import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/appointments.dart'; 
import 'package:url_launcher/url_launcher.dart';

class allOppointment extends StatefulWidget {
  final String name, mobile, taskId, time;
  final String subject;
  final String date;
  final String vehicle;
  final String leadId;
  final double swipeOffset;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const allOppointment({
    super.key,
    required this.name,
    required this.subject,
    required this.date,
    required this.vehicle,
    required this.leadId,
    this.swipeOffset = 0.0,
    this.isFavorite = false,
    required this.onToggleFavorite,
    required this.mobile,
    required this.taskId,
    required this.time,
  });

  @override
  State<allOppointment> createState() => _AllFollowupsItemState();
}

class _AllFollowupsItemState extends State<allOppointment>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _wasCallingPhone = false;

  late SlidableController _slidableController;

  @override
  void initState() {
    super.initState();
    // Register this class as an observer to track app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _slidableController = SlidableController(this);
    _slidableController.animation.addListener(() {
      final isOpen = _slidableController.ratio != 0;
      if (_isActionPaneOpen != isOpen) {
        setState(() {
          _isActionPaneOpen = isOpen;
        });
      }
    });
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    _slidableController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This gets called when app lifecycle state changes
    if (state == AppLifecycleState.resumed && _wasCallingPhone) {
      // App is resumed and we marked that user was making a call
      _wasCallingPhone = false;
      // Show the mail action dialog after a short delay to ensure app is fully resumed
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _mailAction();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      child: InkWell(
        onTap: () {
          if (widget.leadId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowupsDetails(
                  leadId: widget.leadId,
                  isFromFreshlead: false,
                  isFromManager: false,
                  isFromTestdriveOverview: false,
                  refreshDashboard: () async {},
                ),
              ),
            );
          } else {
            print("Invalid leadId");
          }
        },
        child: _buildOverdueCard(context),
      ),
    );
  }

  Widget _buildOverdueCard(BuildContext context) {
    bool isFavoriteSwipe = widget.swipeOffset > 50;
    bool isCallSwipe = widget.swipeOffset < -50;

    return Slidable(
      controller: _slidableController,
      key: ValueKey(widget.leadId), // Always good to set keys
      startActionPane: ActionPane(
        extentRatio: 0.2,
        motion: const ScrollMotion(),
        children: [
          ReusableSlidableAction(
            onPressed: widget.onToggleFavorite, // handle fav toggle
            backgroundColor: Colors.amber,
            icon: widget.isFavorite
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            foregroundColor: Colors.white,
          ),
        ],
      ),

      endActionPane: ActionPane(
        extentRatio: 0.4,
        motion: const StretchMotion(),
        children: [
          if (widget.subject == 'Call')
            ReusableSlidableAction(
              onPressed: _phoneAction,
              backgroundColor: AppColors.colorsBlue,
              icon: Icons.phone,
              foregroundColor: Colors.white,
            ),
          if (widget.subject == 'Send SMS')
            ReusableSlidableAction(
              onPressed: _messageAction,
              backgroundColor: AppColors.colorsBlue,
              icon: Icons.message_rounded,
              foregroundColor: Colors.white,
            ),
          // Edit is always shown
          ReusableSlidableAction(
            onPressed: _mailAction,
            backgroundColor: const Color.fromARGB(255, 231, 225, 225),
            icon: Icons.edit,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Favorite Swipe Overlay
          if (isFavoriteSwipe) Positioned.fill(child: _buildFavoriteOverlay()),

          // Call Swipe Overlay
          if (isCallSwipe) Positioned.fill(child: _buildCallOverlay()),

          // Main Card
          Opacity(
            opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.containerBg,
                borderRadius: BorderRadius.circular(5),
                border: Border(
                  left: BorderSide(
                    width: 8.0,
                    color: widget.isFavorite
                        ? Colors.yellow
                        : AppColors.colorsBlueBar,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildUserDetails(context),
                              _buildVerticalDivider(15),
                              _buildCarModel(context),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildSubjectDetails(context),
                              _date(context),
                              _time(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildNavigationButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _time() {
    DateTime parsedTime = DateFormat("HH:mm:ss").parse(widget.time);
    String formattedTime = DateFormat("ha").format(parsedTime);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        Text(
          formattedTime,
          style: GoogleFonts.poppins(
            color: AppColors.fontColor,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.yellow.withOpacity(0.2),
            Colors.yellow.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(
            widget.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
            color: const Color.fromRGBO(226, 195, 34, 1),
            size: 40,
          ),
          const SizedBox(width: 10),
          Text(
            widget.isFavorite ? 'Unfavorite' : 'Favorite',
            style: GoogleFonts.poppins(
              color: const Color.fromRGBO(187, 158, 0, 1),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.green],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.phone_in_talk, color: Colors.white, size: 30),
          const SizedBox(width: 10),
          Text(
            'Call',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetails(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .35,
      ),
      child: Text(
        maxLines: 1, // Allow up to 2 lines
        overflow: TextOverflow
            .ellipsis, // Show ellipsis if it overflows beyond 2 lines
        softWrap: true,
        widget.name,
        style: AppFont.dashboardName(context),
      ),
    );
  }

  Widget _buildSubjectDetails(BuildContext context) {
    IconData icon;
    if (widget.subject == 'Meeting') {
      icon = Icons.phone_in_talk;
    } else if (widget.subject == 'Provide Quotation') {
      icon = Icons.mail_rounded;
    } else if (widget.subject == 'Showroom appointment') {
      icon = Icons.mail_rounded;
    } else {
      icon = Icons.phone; // fallback icon
    }

    return Row(
      children: [
        Icon(icon, color: AppColors.colorsBlue, size: 18),
        const SizedBox(width: 5),
        // Text('${widget.subject},', style: AppFont.smallText(context)),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .40,
          ),
          child: Text(
            widget.subject,
            style: AppFont.dashboardCarName(context),
            maxLines: 1, // Allow up to 2 lines
            overflow: TextOverflow
                .ellipsis, // Show ellipsis if it overflows beyond 2 lines
            softWrap: true, // Allow wrapping
          ),
        ),
      ],
    );
  }

  // Widget _buildSubjectDetails(BuildContext context) {
  //   return Row(
  //     children: [
  //       const Icon(Icons.phone_in_talk, color: AppColors.colorsBlue, size: 18),
  //       const SizedBox(width: 5),
  //       Text('${widget.subject},', style: AppFont.smallText(context)),
  //     ],
  //   );
  // }

  Widget _date(BuildContext context) {
    String formattedDate = '';
    try {
      DateTime parseDate = DateTime.parse(widget.date);
      if (parseDate.year == DateTime.now().year &&
          parseDate.month == DateTime.now().month &&
          parseDate.day == DateTime.now().day) {
        formattedDate = 'Today';
      } else {
        int day = parseDate.day;
        String suffix = _getDaySuffix(day);
        String month = DateFormat('MMM').format(parseDate);
        formattedDate = '$day$suffix $month';
      }
    } catch (e) {
      formattedDate = widget.date;
    }
    return Row(
      children: [
        const SizedBox(width: 5),
        Text(formattedDate, style: AppFont.smallText(context)),
      ],
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildVerticalDivider(double height) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: height,
      width: 0.1,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.fontColor)),
      ),
    );
  }

  Widget _buildCarModel(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .30,
      ),
      child: Text(
        widget.vehicle,
        style: AppFont.dashboardCarName(context),
        maxLines: 1, // Allow up to 2 lines
        overflow: TextOverflow
            .ellipsis, // Show ellipsis if it overflows beyond 2 lines
        softWrap: true, // Allow wrapping
      ),
    );
  }

  // Widget _buildCarModel(BuildContext context) {
  //   return Text(
  //     widget.vehicle,
  //     style: AppFont.dashboardCarName(context),
  //     overflow: TextOverflow.visible,
  //     softWrap: true,
  //   );
  // }

  bool _isActionPaneOpen = false;
  Widget _buildNavigationButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isActionPaneOpen) {
          _slidableController.close();
          setState(() {
            _isActionPaneOpen = false;
          });
        } else {
          _slidableController.close();
          Future.delayed(Duration(milliseconds: 100), () {
            _slidableController.openEndActionPane();
            setState(() {
              _isActionPaneOpen = true;
            });
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.arrowContainerColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          _isActionPaneOpen
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_rounded,
          size: 25,
          color: Colors.white,
        ),
      ),
    );
  }

  void _phoneAction() {
    print("Call action triggered for ${widget.mobile}");

    // String mobile = item['mobile'] ?? '';

    if (widget.mobile.isNotEmpty) {
      try {
        // Set flag that we're making a phone call
        _wasCallingPhone = true;

        // Simple approach without canLaunchUrl check
        final phoneNumber = 'tel:${widget.mobile}';
        launchUrl(
          Uri.parse(phoneNumber),
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        print('Error launching phone app: $e');

        // Reset flag if there was an error
        _wasCallingPhone = false;
        // Show error message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No phone number available')));
      }
    }
  }

  void _messageAction() {
    print("Message action triggered");
  }

  void _mailAction() {
    print("Mail action triggered");

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          // child: FollowupsEdit(onFormSubmit: () {}, taskId: widget.taskId),
          child: AppointmentsEdit(onFormSubmit: () {}, taskId: widget.taskId),
        );
      },
    );
  }
}

class ReusableSlidableAction extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final Color? foregroundColor;
  final double iconSize;

  const ReusableSlidableAction({
    Key? key,
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    this.foregroundColor,
    this.iconSize = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      padding: EdgeInsets.zero,
      onPressed: (context) => onPressed(),
      backgroundColor: backgroundColor,
      child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
    );
  }
}

class AllOppintment extends StatefulWidget {
  final List<dynamic> allFollowups;
  final bool isNested;

  const AllOppintment({
    super.key,
    required this.allFollowups,
    this.isNested = false,
  });

  @override
  State<AllOppintment> createState() => _AllOppintmentState();
}

class _AllOppintmentState extends State<AllOppintment> {
  List<bool> _favorites = [];

  @override
  void initState() {
    super.initState();
    _initializeFavorites();
  }

  @override
  void didUpdateWidget(AllOppintment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allFollowups != oldWidget.allFollowups) {
      _initializeFavorites();
    }
  }

  void _initializeFavorites() {
    _favorites = List.generate(
      widget.allFollowups.length,
      (index) => widget.allFollowups[index]['favourite'] == true,
    );
  }

  // void _toggleFavorite(int index) {
  //   setState(() {
  //     _favorites[index] = !_favorites[index];
  //   });
  // }

  Future<void> _toggleFavorite(String taskId, int index) async {
    bool currentStatus = widget.allFollowups[index]['favourite'] ?? false;
    bool newFavoriteStatus = !currentStatus;

    final success = await LeadsSrv.favoriteEvent(taskId: taskId);
    if (success) {
      setState(() {
        widget.allFollowups[index]['favourite'] = newFavoriteStatus;
      });

      // if (widget.onFavoriteToggle != null) {
      //   widget.onFavoriteToggle!(taskId, newFavoriteStatus);
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allFollowups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No oppointment available",
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isNested)
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 15, 0, 0),
            child: Text(
              "All Appointment",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: widget.isNested
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          itemCount: widget.allFollowups.length,
          itemBuilder: (context, index) {
            var item = widget.allFollowups[index];
            print('Item at index $index: $item');

            String eventId = item['task_id'];

            return GestureDetector(
              child: allOppointment(
                key: ValueKey(eventId),
                name: item['name'],
                subject: item['subject'] ?? 'Meeting',
                date: item['due_date'] ?? '',
                vehicle: item['PMI'] ?? 'Range Rover Velar',
                leadId: item['lead_id'],
                mobile: item['mobile'] ?? '',
                time: item['time'] ?? '',
                taskId: item['task_id'] ?? '',
                // refreshDashboard: widget.refreshDashboard,
                isFavorite: item['favourite'] ?? false,
                // swipeOffset: swipeOffset,
                // fetchDashboardData: () {},
                onToggleFavorite: () {
                  _toggleFavorite(eventId, index);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
