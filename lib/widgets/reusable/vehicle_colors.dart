import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/leads_srv.dart';


typedef VehicleColorSelectedCallback =
    void Function(Map<String, dynamic> selectedVehicle);

class VehicleColors extends StatefulWidget {
  final VehicleColorSelectedCallback? VehicleColorSelected;
  const VehicleColors({
    super.key,
    this.VehicleColorSelected
  });

  @override
  State<VehicleColors> createState() => _VehicleColorsState();
}

class _VehicleColorsState extends State<VehicleColors> {
  bool _isLoadingColor = false;
  bool _hasLoadedColors = false;
  List<Map<String, dynamic>> _allColors = [];
  List<Map<String, dynamic>> _searchResultsColor = [];
  String? selectedColorName;
  String? selectedVehicleColorId;
  String? selectedUrl;

  final TextEditingController _searchControllerVehicleColor =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllColors();
  }

  @override
  void dispose() {
    _searchControllerVehicleColor.dispose();
    super.dispose();
  }

  Future<void> _loadAllColors() async {
    if (_hasLoadedColors) return;

    setState(() {
      _isLoadingColor = true;
    });

    try {
      final result =
          await LeadsSrv.getAllVehicles(); // Update if API is for colors

      if (result['success']) {
        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
          result['data'],
        );
        setState(() {
          _allColors = data;
          _searchResultsColor = data; // preload suggestions
          _hasLoadedColors = true;
        });
      } else {
        _showError(result['error'] ?? 'Failed to load colors');
      }
    } catch (e) {
      _showError('Error loading colors: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingColor = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchResultsColor = _allColors
          .where(
            (item) =>
                item['color_name']?.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: AppFont.dropDowmLabel(context)),
        const SizedBox(height: 10),
        Container(
          height: MediaQuery.of(context).size.height * 0.055,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColors.containerBg,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchControllerVehicleColor,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText: selectedColorName ?? 'Search Color',
                    hintStyle: TextStyle(
                      color: selectedColorName != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: AppColors.fontColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingColor)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_searchResultsColor.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResultsColor.length,
              itemBuilder: (context, index) {
                final result = _searchResultsColor[index];
                final imageUrl = result['image_url'];

                return ListTile(
                  onTap: () {
                    setState(() {
                      FocusScope.of(context).unfocus();
                      selectedVehicleColorId = result['color_id'];
                      selectedColorName = result['color_name'];
                      selectedUrl = imageUrl;
                      _searchControllerVehicleColor.text =
                          result['color_name'] ?? '';
                      _searchResultsColor.clear();
                    });
                  },
                  title: Text(
                    result['color_name'] ?? 'No Name',
                    style: GoogleFonts.poppins(
                      color: selectedVehicleColorId == result['color_id']
                          ? Colors.black
                          : AppColors.fontBlack,
                    ),
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.error),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          )
                        : const Icon(
                            Icons.invert_colors_rounded,
                            color: Colors.grey,
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
