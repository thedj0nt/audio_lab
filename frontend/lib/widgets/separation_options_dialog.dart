import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';

class SeparationOptionsDialog extends StatefulWidget {
  final PlatformFile pickedFile;
  final String defaultTitle;
  final Function(String title, String stems) onUploadTriggered;

  const SeparationOptionsDialog({
    super.key,
    required this.pickedFile,
    required this.defaultTitle,
    required this.onUploadTriggered,
  });

  @override
  State<SeparationOptionsDialog> createState() =>
      _SeparationOptionsDialogState();
}

class _SeparationOptionsDialogState extends State<SeparationOptionsDialog> {
  late final TextEditingController _titleController;
  final Set<String> _selectedStems = {'vocals', 'drums', 'bass', 'other'};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleStem(String key) {
    setState(() {
      if (_selectedStems.contains(key)) {
        if (_selectedStems.length > 1) {
          _selectedStems.remove(key);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one stem must be selected.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _selectedStems.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.pickedFile.name;
    final double fileSizeMb = widget.pickedFile.size / (1024 * 1024);

    // Choose model engine name and FLOPS details based on selected stems
    final bool use6s =
        _selectedStems.contains('guitar') || _selectedStems.contains('piano');
    final String engineName =
        use6s ? 'ECHO-SEPARATE-V6 (6-STEM)' : 'ECHO-SEPARATE-V4 (4-STEM)';
    final String processingPower =
        use6s ? '18s @ 12.4 TFLOPS' : '10s @ 8.2 TFLOPS';

    return Consumer(
      builder: (context, ref, child) {
        final colors = ref.watch(themeColorsProvider);

        return Dialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border, width: 1.5),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECT SEPARATION TRACKS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: colors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: colors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ACTIVE FILE: ${filename.toUpperCase()} (${fileSizeMb.toStringAsFixed(2)} MB)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: colors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Song/Session Title input
                Text(
                  'SESSION TITLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.background,
                    hintText: 'Enter session title...',
                    hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Grid of 6 stems
                Text(
                  'CHOOSE STEMS TO GENERATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStemCard(
                        colors, 'vocals', 'VOCALS', Icons.mic_none_rounded),
                    _buildStemCard(
                        colors, 'drums', 'DRUMS', Icons.album_rounded),
                    _buildStemCard(
                        colors, 'bass', 'BASS', Icons.graphic_eq_rounded),
                    _buildStemCard(
                        colors, 'piano', 'PIANO', Icons.piano_rounded),
                    _buildStemCard(
                        colors, 'guitar', 'GUITAR', Icons.music_note_rounded),
                    _buildStemCard(
                        colors, 'other', 'OTHERS', Icons.tune_rounded),
                  ],
                ),
                const SizedBox(height: 20),

                // Footer metadata badges
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODEL ENGINE',
                              style: TextStyle(
                                fontSize: 8,
                                fontFamily: 'monospace',
                                color:
                                    colors.textSecondary.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              engineName,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'EST. PROCESSING',
                            style: TextStyle(
                              fontSize: 8,
                              fontFamily: 'monospace',
                              color:
                                  colors.textSecondary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            processingPower,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Large Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter a session title.')),
                        );
                        return;
                      }
                      if (_selectedStems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please select at least one stem.')),
                        );
                        return;
                      }
                      Navigator.of(context).pop();
                      widget.onUploadTriggered(title, _selectedStems.join(','));
                    },
                    child: const Text(
                      'START SEPARATION ⚡',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Once initiated, cloud AI resources will split stems in background. May take up to 20s.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStemCard(
      AppThemeColors colors, String key, String displayName, IconData icon) {
    final isSelected = _selectedStems.contains(key);
    return GestureDetector(
      onTap: () => _toggleStem(key),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.08)
              : colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? colors.accent : colors.textSecondary,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color:
                        isSelected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
