import os
import shutil
import subprocess
from django.conf import settings
from django.core.files import File
from celery import shared_task
from .models import Project, Track

@shared_task
def process_audio_separation(project_id):
    """
    Executes actual Meta Demucs AI separation on a Project's primary track.
    Splits the uploaded stereo mix into 4 separate stems (Vocals, Drums, Bass, Other),
    saves them to Project tracks database, and cleans up temporary outputs.
    """
    print(f"[CELERY AI WORKER] 🚀 Starting AI separation for Project ID: {project_id}")
    
    try:
        project = Project.objects.get(id=project_id)
        
        # We separate the primary track uploaded (the complete mix)
        mix_track = project.tracks.first()
        if not mix_track:
            raise Exception("No input mix track found in project database.")
            
        if not mix_track.file or not os.path.exists(mix_track.file.path):
            raise Exception(f"Input audio file does not exist on disk path: {mix_track.file}")
            
        # Update Project status to Processing
        project.status = 'Processing'
        project.save()
        print(f"[CELERY AI WORKER] ⏳ Status set to Processing. Initiating Meta Demucs model CLI execution...")
        
        file_path = mix_track.file.path
        
        # --- Run Audio Analysis (BPM, Scale, Duration) ---
        print(f"[CELERY AI WORKER] 🎵 Running Librosa audio analysis (BPM, Key Scale, Duration)...")
        try:
            import numpy as np
            import librosa
            
            # 1. Extract exact duration (seconds)
            duration = int(round(librosa.get_duration(path=file_path)))
            project.duration = duration
            print(f"[CELERY AI WORKER] 🕒 Extracted duration: {duration} seconds")
            project.save()
            
            # 2. Load 30 seconds of mix file for fast tempo & key correlations
            y, sr = librosa.load(file_path, sr=None, duration=30.0)
            
            # 3. Estimate Tempo (BPM)
            tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
            bpm = int(round(float(tempo)))
            project.bpm = bpm
            print(f"[CELERY AI WORKER] 🥁 Estimated tempo: {bpm} BPM")
            project.save()
            
            # 4. Estimate Key Signature/Scale using Pitch Class profiling
            chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
            chroma_vals = chroma.sum(axis=1)
            
            # Krumhansl-Schmuckler profiles correlation vectors
            major_profile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
            minor_profile = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
            
            notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
            
            major_corrs = [float(np.corrcoef(chroma_vals, np.roll(major_profile, i))[0, 1]) for i in range(12)]
            minor_corrs = [float(np.corrcoef(chroma_vals, np.roll(minor_profile, i))[0, 1]) for i in range(12)]
            
            best_major_idx = np.argmax(major_corrs)
            best_minor_idx = np.argmax(minor_corrs)
            
            if major_corrs[best_major_idx] > minor_corrs[best_minor_idx]:
                scale = f"{notes[best_major_idx]} Major"
            else:
                scale = f"{notes[best_minor_idx]} Minor"
                
            project.scale = scale
            print(f"[CELERY AI WORKER] 🎹 Estimated key scale: {scale}")
            project.save()
            
        except Exception as analysis_err:
            print(f"[CELERY AI WORKER] ⚠️ Audio analysis failed (proceeding with separation): {analysis_err}")
        # Get filename without extension
        filename_without_ext = os.path.splitext(os.path.basename(file_path))[0]
        
        # Setup temporary directories under media/separated
        temp_output_dir = os.path.join(settings.MEDIA_ROOT, 'separated')
        os.makedirs(temp_output_dir, exist_ok=True)
        
        # Read selected stems
        selected_keys = []
        if project.stems:
            selected_keys = [s.strip().lower() for s in project.stems.split(',') if s.strip()]
        
        # If no stems selected, default to standard 4 stems
        if not selected_keys:
            selected_keys = ['vocals', 'drums', 'bass', 'other']

        # Determine which model is required (guitar/piano need the 6-stem model 'htdemucs_6s')
        use_6s = 'guitar' in selected_keys or 'piano' in selected_keys
        model_name = "htdemucs_6s" if use_6s else "htdemucs"
        print(f"[CELERY AI WORKER] 🎵 Chosen model: {model_name} (Stems requested: {selected_keys})")

        # Map keys to their corresponding demucs output keys
        demucs_keys_needed = set()
        for k in selected_keys:
            if k == 'synth':
                demucs_keys_needed.add('other')
            elif k == 'keyboard':
                demucs_keys_needed.add('piano')
            else:
                demucs_keys_needed.add(k)

        # Run Demucs CLI using Python's subprocess module
        cmd = [
            "demucs",
            "-n",
            model_name,
            "--mp3",
            "-o",
            temp_output_dir,
            file_path
        ]
        
        print(f"[CELERY AI WORKER] ⚡ Executing CLI: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        print("[CELERY AI WORKER] 📺 Demucs output log completed successfully.")
        
        # Demucs places files inside: temp_output_dir/<model_name>/<filename_without_ext>/
        separated_dir = os.path.join(temp_output_dir, model_name, filename_without_ext)
        if not os.path.exists(separated_dir):
            raise Exception(f"Demucs execution did not generate expected stems folder at: {separated_dir}")
            
        # We parse the output stems generated by the model
        stems = ['vocals.mp3', 'drums.mp3', 'bass.mp3', 'other.mp3']
        if use_6s:
            stems += ['guitar.mp3', 'piano.mp3']
        
        for stem_file in stems:
            stem_key = os.path.splitext(stem_file)[0]
            
            # Skip if this demucs stem was not requested by the user
            if stem_key not in demucs_keys_needed:
                print(f"[CELERY AI WORKER] ⏭️ Skipping unselected stem: {stem_key}")
                continue
                
            stem_path = os.path.join(separated_dir, stem_file)
            
            if os.path.exists(stem_path):
                # Format name nicely depending on what was selected
                stem_name = stem_key.title()
                if stem_key == 'other':
                    if 'synth' in selected_keys and 'other' in selected_keys:
                        stem_name = "Synth / Others"
                    elif 'synth' in selected_keys:
                        stem_name = "Synth"
                    else:
                        stem_name = "Synth / Others"
                elif stem_key == 'piano':
                    stem_name = "Piano / Keyboard"
                
                print(f"[CELERY AI WORKER] 💾 Importing separated stem: {stem_name} ({stem_file})")
                
                # Save dynamically via Django Storage File interface
                with open(stem_path, 'rb') as f:
                    new_track = Track(project=project, name=stem_name)
                    # Copies stem into our permanent projects directory dynamically
                    new_track.file.save(stem_file, File(f), save=True)
            else:
                print(f"[CELERY AI WORKER] ⚠️ Warning: Expected stem file '{stem_file}' not found at {stem_path}")
                
        # Cleanup temporary files generated by Demucs to conserve server disk space
        shutil.rmtree(separated_dir, ignore_errors=True)
        print(f"[CELERY AI WORKER] 🧹 Temporary folder cleaned up.")
        
        # Complete the project background state
        project.status = 'Completed'
        project.save()
        print(f"[CELERY AI WORKER] 🎉 AI separation successfully completed for Project ID: {project_id}")
        
    except Project.DoesNotExist:
        print(f"[CELERY AI WORKER] ❌ Error: Project with ID {project_id} does not exist.")
    except Exception as e:
        print(f"[CELERY AI WORKER] ❌ Critical Error during Demucs execution: {str(e)}")
        try:
            # Fallback error status representation
            project = Project.objects.get(id=project_id)
            project.status = 'Failed'
            project.save()
        except Exception:
            pass
