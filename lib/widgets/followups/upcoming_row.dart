import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
import 'package:url_launcher/url_launcher.dart';

class FollowupsUpcoming extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  final List<dynamic> upcomingFollowups;
  final bool isNested;
  final Function(String, bool)? onFavoriteToggle;

  const FollowupsUpcoming({
    super.key,
    required this.upcomingFollowups,
    required this.isNested,
    this.onFavoriteToggle,
    required this.refreshDashboard,
  });

  @override
  State<FollowupsUpcoming> createState() => _FollowupsUpcomingState();
}

class _FollowupsUpcomingState extends State<FollowupsUpcoming> {
  final Map<String, double> _swipeOffsets = {};
  late bool isFav;
  Future<void> _toggleFavorite(String taskId, int index) async {
    bool currentStatus = widget.upcomingFollowups[index]['favourite'] ?? false;
    bool newFavoriteStatus = !currentStatus;

    final success = await LeadsSrv.favorite(taskId: taskId);

    if (success) {
      setState(() {
        widget.upcomingFollowups[index]['favourite'] = newFavoriteStatus;
      });

      if (widget.onFavoriteToggle != null) {
        widget.onFavoriteToggle!(taskId, newFavoriteStatus);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.upcomingFollowups.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No upcoming followups available ',
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: widget.isNested
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: widget.upcomingFollowups.length,
      itemBuilder: (context, index) {
        var item = widget.upcomingFollowups[index];

        if (!(item.containsKey('name') &&
            item.containsKey('due_date') &&
            item.containsKey('lead_id') &&
            item.containsKey('task_id'))) {
          return ListTile(title: Text('Invalid data at index $index'));
        }

        String taskId = item['task_id'];
        double swipeOffset = _swipeOffsets[taskId] ?? 0;

        return GestureDetector(
          child: UpcomingFollowupItem(
            key: ValueKey(item['task_id']),
            name: item['name'],
            date: item['due_date'],
            mobile: item['mobile'],
            subject: item['subject'] ?? '',
            vehicle: item['PMI'] ?? 'Range Rover Velar',
            leadId: item['lead_id'],
            taskId: taskId,
            isFavorite: item['favourite'] ?? false,
            swipeOffset: swipeOffset,
            refreshDashboard: widget.refreshDashboard,
            onToggleFavorite: () {
              _toggleFavorite(taskId, index);
            },
          ),
        );
      },
    );
  }
}

class UpcomingFollowupItem extends StatefulWidget {
  final String name, mobile, taskId;
  final String subject;
  final String date;
  final String vehicle;
  final String leadId;
  final double swipeOffset;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final Future<void> Function() refreshDashboard;

  const UpcomingFollowupItem({
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
    required this.refreshDashboard,
  });

  @override
  State<UpcomingFollowupItem> createState() => _overdueeFollowupsItemState();
}

class _overdueeFollowupsItemState extends State<UpcomingFollowupItem>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _wasCallingPhone = false;
  late SlidableController _slidableController;
  bool _isActionPaneOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _slidableController = SlidableController(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slidableController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasCallingPhone) {
      _wasCallingPhone = false;
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
                  refreshDashboard: widget.refreshDashboard,
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
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    return Slidable(
      key: ValueKey(widget.leadId), // Always good to set keys
      controller: _slidableController,

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
              backgroundColor: Colors.blue,
              icon: Icons.phone,
              foregroundColor: Colors.white,
            ),
          if (widget.subject == 'Send SMS')
            ReusableSlidableAction(
              onPressed: _messageAction,
              backgroundColor: Colors.blueGrey,
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
          // Main Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.containerBg,
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: BorderSide(
                  width: 8.0,
                  color: widget.isFavorite
                      ? Colors.yellow
                      : AppColors.sideGreen,
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

                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildSubjectDetails(context),
                            _date(context),
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
        ],
      ),
    );
  }

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
              : Icons
                    .arrow_back_ios_rounded, // When closed, show back arrow (to open)
          size: 25,
          color: Colors.white,
        ),
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
    if (widget.subject == 'Call') {
      icon = Icons.phone_in_talk;
    } else if (widget.subject == 'Send SMS') {
      icon = Icons.mail_rounded;
    } else if (widget.subject == 'Provide quotation') {
      icon = Icons.mail_rounded;
    } else if (widget.subject == 'Send Email') {
      icon = Icons.mail_rounded;
    } else {
      icon = Icons.phone; // fallback icon
    }

    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 18),
        const SizedBox(width: 5),
        Text('${widget.subject},', style: AppFont.smallText(context)),
      ],
    );
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

  void _phoneAction() {
    print("Call action triggered for ${widget.mobile}");

    if (widget.mobile.isNotEmpty) {
      try {
        // Set flag that we're making a phone call
        _wasCallingPhone = true;

        // Use the same approach as _handleCall - no launch mode specified
        launchUrl(Uri.parse('tel:${widget.mobile}'));

        print('Phone dialer launched');
      } catch (e) {
        print('Error launching phone app: $e');

        // Reset flag if there was an error
        _wasCallingPhone = false;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
    }
  }

  // void _messageAction() {
  //   print("Message action triggered");
  // }

  void _messageAction() {
    print("Message action triggered for ${widget.mobile}");

    if (widget.mobile.isNotEmpty) {
      try {
        // Set flag that we're opening SMS (if you want to track this)
        // _wasOpeningSMS = true;

        // Launch SMS app with the mobile number
        launchUrl(Uri.parse('sms:${widget.mobile}'));

        print('SMS app launched');
      } catch (e) {
        print('Error launching SMS app: $e');

        // Reset flag if there was an error (if you're using the flag)
        // _wasOpeningSMS = false;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch SMS app')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
    }
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
          child: FollowupsEdit(onFormSubmit: () {}, taskId: widget.taskId),
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


// class UpcomingFollowupItem extends StatelessWidget {
//   final String name, date, vehicle, leadId, taskId, subject, mobile;
//   final bool isFavorite;
//   final double swipeOffset;
//   final VoidCallback fetchDashboardData;

//   const UpcomingFollowupItem({
//     super.key,
//     required this.name,
//     required this.date,
//     required this.vehicle,
//     required this.leadId,
//     required this.taskId,
//     required this.isFavorite,
//     required this.swipeOffset,
//     required this.fetchDashboardData,
//     required this.subject,
//     required this.mobile,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
//       child: _buildFollowupCard(context),
//     );
//   }

//   Widget _buildFollowupCard(BuildContext context) {
//     bool isFavoriteSwipe = swipeOffset > 50;
//     bool isCallSwipe = swipeOffset < -50;

//     // Gradient background for swipe
//     LinearGradient _buildSwipeGradient() {
//       if (isFavoriteSwipe) {
//         return const LinearGradient(
//           colors: [
//             Color.fromRGBO(239, 206, 29, 0.67),
//             // Colors.yellow.withOpacity(0.2),
//             // Colors.yellow.withOpacity(0.8)
//             Color.fromRGBO(239, 206, 29, 0.67)
//           ],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         );
//       } else if (isCallSwipe) {
//         return LinearGradient(
//           colors: [
//             Colors.green.withOpacity(0.2),
//             Colors.green.withOpacity(0.2)
//           ],
//           begin: Alignment.centerRight,
//           end: Alignment.centerLeft,
//         );
//       }
//       return const LinearGradient(
//         colors: [AppColors.containerBg, AppColors.containerBg],
//         begin: Alignment.centerLeft,
//         end: Alignment.centerRight,
//       );
//     }

//     return Stack(
//       children: [
//         // Favorite Swipe Overlay
//         if (isFavoriteSwipe)
//           Positioned.fill(
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.yellow.withOpacity(0.2),
//                     Colors.yellow.withOpacity(0.8)
//                   ],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Center(
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     const SizedBox(width: 15),
//                     Icon(
//                         isFavorite
//                             ? Icons.star_outline_rounded
//                             : Icons.star_rounded,
//                         color: Color.fromRGBO(226, 195, 34, 1),
//                         size: 40),
//                     const SizedBox(width: 10),
//                     Text(isFavorite ? 'Unfavorite' : 'Favorite',
//                         style: GoogleFonts.poppins(
//                             color: Color.fromRGBO(187, 158, 0, 1),
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold)),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//         // Call Swipe Overlay
//         if (isCallSwipe)
//           Positioned.fill(
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Colors.green, Colors.green],
//                   begin: Alignment.centerRight,
//                   end: Alignment.centerLeft,
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Center(
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     const SizedBox(
//                       width: 10,
//                     ),
//                     const Icon(Icons.phone_in_talk,
//                         color: Colors.white, size: 30),
//                     const SizedBox(width: 10),
//                     Text('Call',
//                         style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold)),
//                     const SizedBox(width: 5),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//         // Main Container
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//           decoration: BoxDecoration(
//             gradient: _buildSwipeGradient(),
//             borderRadius: BorderRadius.circular(7),
//             border: Border(
//               left: BorderSide(
//                 width: 8.0,
//                 color: isFavorite
//                     ? (isCallSwipe
//                         ? Colors.green
//                             .withOpacity(0.9) // Green when swiping for a call
//                         : Colors.yellow.withOpacity(isFavoriteSwipe
//                             ? 0.1
//                             : 0.9)) // Keep yellow when favorite
//                     : (isFavoriteSwipe
//                         ? Colors.yellow.withOpacity(0.1)
//                         : (isCallSwipe ? Colors.green : AppColors.sideGreen)),
//               ),
//             ),
//           ),
//           child: Opacity(
//             opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Row(
//                   children: [
//                     // Conditional favorite star
//                     // if (isFavorite || isFavoriteSwipe)
//                     //   Icon(
//                     //     Icons.star_rounded,
//                     //     color: isFavoriteSwipe
//                     //         ? Colors.white
//                     //         : AppColors.starColorsYellow,
//                     //     size: 40,
//                     //   ),
//                     const SizedBox(width: 8),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             _buildUserDetails(context),
//                             _buildVerticalDivider(15),
//                             _buildCarModel(context),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             _buildSubjectDetails(context),
//                             _date(context),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 _buildNavigationButton(context),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildNavigationButton(BuildContext context) {
//     // ✅ Accept context
//     return GestureDetector(
//       onTap: () {
//         if (leadId.isNotEmpty) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => FollowupsDetails(leadId: leadId)),
//           );
//         } else {
//           print("Invalid leadId");
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.all(3),
//         decoration: BoxDecoration(
//             color: AppColors.arrowContainerColor,
//             borderRadius: BorderRadius.circular(30)),
//         child: const Icon(Icons.arrow_forward_ios_rounded,
//             size: 25, color: Colors.white),
//       ),
//     );
//   }

//   // Widget _buildUserDetails(BuildContext context) {
//   //   return Text(name,
//   //       textAlign: TextAlign.end, style: AppFont.dashboardName(context));
//   // }

//   Widget _buildUserDetails(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(name, style: AppFont.dashboardName(context)),
//         // const SizedBox(height: 5),
//       ],
//     );
//   }

//   Widget _buildSubjectDetails(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Icon(Icons.phone_in_talk, color: Colors.blue, size: 18),
//         const SizedBox(width: 5),
//         Text('$subject,', style: AppFont.smallText(context)),
//       ],
//     );
//   }

//   Widget _date(BuildContext context) {
//     String formattedDate = '';

//     try {
//       DateTime parseDate = DateTime.parse(date);

//       // Check if the date is today
//       if (parseDate.year == DateTime.now().year &&
//           parseDate.month == DateTime.now().month &&
//           parseDate.day == DateTime.now().day) {
//         formattedDate = 'Today';
//       } else {
//         // If not today, format it as "26th March"
//         int day = parseDate.day;
//         String suffix = _getDaySuffix(day);
//         String month = DateFormat('MMM').format(parseDate); // Full month name
//         formattedDate = '${day}$suffix $month';
//       }
//     } catch (e) {
//       formattedDate = date; // Fallback if date parsing fails
//     }

//     return Row(
//       children: [
//         const SizedBox(width: 5),
//         Text(formattedDate, style: AppFont.smallText(context)),
//       ],
//     );
//   }

// // Helper method to get the suffix for the day (e.g., "st", "nd", "rd", "th")
//   String _getDaySuffix(int day) {
//     if (day >= 11 && day <= 13) {
//       return 'th';
//     }
//     switch (day % 10) {
//       case 1:
//         return 'st';
//       case 2:
//         return 'nd';
//       case 3:
//         return 'rd';
//       default:
//         return 'th';
//     }
//   }

//   Widget _buildVerticalDivider(double height) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 3, left: 10, right: 10),
//       height: height,
//       width: 0.1,
//       decoration: const BoxDecoration(
//           border: Border(right: BorderSide(color: AppColors.fontColor))),
//     );
//   }

//   Widget _buildCarModel(BuildContext context) {
//     return Text(
//       vehicle,
//       textAlign: TextAlign.start,
//       style: AppFont.dashboardCarName(context),
//       softWrap: true,
//       overflow: TextOverflow.visible,
//     );
//   }
// }















// class UpcomingFollowupItem extends StatelessWidget {
//   final String name, date, vehicle, leadId, taskId, subject, mobile;
//   final bool isFavorite;
//   final double swipeOffset;
//   final VoidCallback fetchDashboardData;

//   const UpcomingFollowupItem({
//     super.key,
//     required this.name,
//     required this.date,
//     required this.vehicle,
//     required this.leadId,
//     required this.taskId,
//     required this.isFavorite,
//     required this.swipeOffset,
//     required this.fetchDashboardData,
//     required this.subject,
//     required this.mobile,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
//       child: _buildFollowupCard(context),
//     );
//   }

//   Widget _buildFollowupCard(BuildContext context) {
//     bool isFavoriteSwipe = swipeOffset > 50;
//     bool isCallSwipe = swipeOffset < -50;

//     // Gradient background for swipe
//     LinearGradient _buildSwipeGradient() {
//       if (isFavoriteSwipe) {
//         return const LinearGradient(
//           colors: [
//             Color.fromRGBO(239, 206, 29, 0.67),
//             // Colors.yellow.withOpacity(0.2),
//             // Colors.yellow.withOpacity(0.8)
//             Color.fromRGBO(239, 206, 29, 0.67)
//           ],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         );
//       } else if (isCallSwipe) {
//         return LinearGradient(
//           colors: [
//             Colors.green.withOpacity(0.2),
//             Colors.green.withOpacity(0.2)
//           ],
//           begin: Alignment.centerRight,
//           end: Alignment.centerLeft,
//         );
//       }
//       return const LinearGradient(
//         colors: [AppColors.containerBg, AppColors.containerBg],
//         begin: Alignment.centerLeft,
//         end: Alignment.centerRight,
//       );
//     }

//     return Stack(
//       children: [
//         // Favorite Swipe Overlay
//         if (isFavoriteSwipe)
//           Positioned.fill(
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.yellow.withOpacity(0.2),
//                     Colors.yellow.withOpacity(0.8)
//                   ],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Center(
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     const SizedBox(width: 15),
//                     Icon(
//                         isFavorite
//                             ? Icons.star_outline_rounded
//                             : Icons.star_rounded,
//                         color: Color.fromRGBO(226, 195, 34, 1),
//                         size: 40),
//                     const SizedBox(width: 10),
//                     Text(isFavorite ? 'Unfavorite' : 'Favorite',
//                         style: GoogleFonts.poppins(
//                             color: Color.fromRGBO(187, 158, 0, 1),
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold)),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//         // Call Swipe Overlay
//         if (isCallSwipe)
//           Positioned.fill(
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Colors.green, Colors.green],
//                   begin: Alignment.centerRight,
//                   end: Alignment.centerLeft,
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Center(
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     const SizedBox(
//                       width: 10,
//                     ),
//                     const Icon(Icons.phone_in_talk,
//                         color: Colors.white, size: 30),
//                     const SizedBox(width: 10),
//                     Text('Call',
//                         style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold)),
//                     const SizedBox(width: 5),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//         // Main Container
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//           decoration: BoxDecoration(
//             gradient: _buildSwipeGradient(),
//             borderRadius: BorderRadius.circular(7),
//             border: Border(
//               left: BorderSide(
//                 width: 8.0,
//                 color: isFavorite
//                     ? (isCallSwipe
//                         ? Colors.green
//                             .withOpacity(0.9) // Green when swiping for a call
//                         : Colors.yellow.withOpacity(isFavoriteSwipe
//                             ? 0.1
//                             : 0.9)) // Keep yellow when favorite
//                     : (isFavoriteSwipe
//                         ? Colors.yellow.withOpacity(0.1)
//                         : (isCallSwipe ? Colors.green : AppColors.sideGreen)),
//               ),
//             ),
//           ),
//           child: Opacity(
//             opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Row(
//                   children: [
//                     // Conditional favorite star
//                     // if (isFavorite || isFavoriteSwipe)
//                     //   Icon(
//                     //     Icons.star_rounded,
//                     //     color: isFavoriteSwipe
//                     //         ? Colors.white
//                     //         : AppColors.starColorsYellow,
//                     //     size: 40,
//                     //   ),
//                     const SizedBox(width: 8),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             _buildUserDetails(context),
//                             _buildVerticalDivider(15),
//                             _buildCarModel(context),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             _buildSubjectDetails(context),
//                             _date(context),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 _buildNavigationButton(context),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildNavigationButton(BuildContext context) {
//     // ✅ Accept context
//     return GestureDetector(
//       onTap: () {
//         if (leadId.isNotEmpty) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => FollowupsDetails(leadId: leadId)),
//           );
//         } else {
//           print("Invalid leadId");
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.all(3),
//         decoration: BoxDecoration(
//             color: AppColors.arrowContainerColor,
//             borderRadius: BorderRadius.circular(30)),
//         child: const Icon(Icons.arrow_forward_ios_rounded,
//             size: 25, color: Colors.white),
//       ),
//     );
//   }

//   // Widget _buildUserDetails(BuildContext context) {
//   //   return Text(name,
//   //       textAlign: TextAlign.end, style: AppFont.dashboardName(context));
//   // }

//   Widget _buildUserDetails(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(name, style: AppFont.dashboardName(context)),
//         // const SizedBox(height: 5),
//       ],
//     );
//   }

//   Widget _buildSubjectDetails(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Icon(Icons.phone_in_talk, color: Colors.blue, size: 18),
//         const SizedBox(width: 5),
//         Text('$subject,', style: AppFont.smallText(context)),
//       ],
//     );
//   }

//   Widget _date(BuildContext context) {
//     String formattedDate = '';

//     try {
//       DateTime parseDate = DateTime.parse(date);

//       // Check if the date is today
//       if (parseDate.year == DateTime.now().year &&
//           parseDate.month == DateTime.now().month &&
//           parseDate.day == DateTime.now().day) {
//         formattedDate = 'Today';
//       } else {
//         // If not today, format it as "26th March"
//         int day = parseDate.day;
//         String suffix = _getDaySuffix(day);
//         String month = DateFormat('MMM').format(parseDate); // Full month name
//         formattedDate = '${day}$suffix $month';
//       }
//     } catch (e) {
//       formattedDate = date; // Fallback if date parsing fails
//     }

//     return Row(
//       children: [
//         const SizedBox(width: 5),
//         Text(formattedDate, style: AppFont.smallText(context)),
//       ],
//     );
//   }

// // Helper method to get the suffix for the day (e.g., "st", "nd", "rd", "th")
//   String _getDaySuffix(int day) {
//     if (day >= 11 && day <= 13) {
//       return 'th';
//     }
//     switch (day % 10) {
//       case 1:
//         return 'st';
//       case 2:
//         return 'nd';
//       case 3:
//         return 'rd';
//       default:
//         return 'th';
//     }
//   }

//   Widget _buildVerticalDivider(double height) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 3, left: 10, right: 10),
//       height: height,
//       width: 0.1,
//       decoration: const BoxDecoration(
//           border: Border(right: BorderSide(color: AppColors.fontColor))),
//     );
//   }

//   Widget _buildCarModel(BuildContext context) {
//     return Text(
//       vehicle,
//       textAlign: TextAlign.start,
//       style: AppFont.dashboardCarName(context),
//       softWrap: true,
//       overflow: TextOverflow.visible,
//     );
//   }
// }


 