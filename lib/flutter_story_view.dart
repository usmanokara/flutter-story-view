import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_story_view/file_downloader.dart';
import 'package:flutter_story_view/models/story_item.dart';
import 'package:flutter_story_view/models/user_info.dart';
import 'package:flutter_story_view/widgets/story_image.dart';
import 'package:flutter_story_view/widgets/story_indicator.dart';
import 'package:flutter_story_view/widgets/story_video.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// A StatefulWidget that displays a series of story items with a customizable
/// progress indicator and user-defined callback functions for navigation and
/// completion events.
///
/// The `FlutterStoryView` takes a list of `StoryItem` objects, and displays them
/// one at a time, advancing to the next item after a specified duration.
///
/// The widget also provides a set of callback functions that can be used to
/// handle user interactions, such as tapping on the screen to pause, resume,
/// or navigate between story items.
///
/// The `onComplete` callback is triggered when all items have been displayed,
/// while the `onPageChanged` callback is triggered every time the currently
/// displayed item changes.

/// [OnPageChanged] is called when a story item changes
typedef OnPageChanged(int);

class FlutterStoryView extends StatefulWidget {
  /// This Calls when story is completed
  final VoidCallback onComplete;

  /// [OnPageChanged] is called when a story item changes
  final OnPageChanged onPageChanged;

  final VoidCallback? onMenuTapListener;

  final List<StoryItem> storyItems;
  // Optional caption for the story
  final String? caption;

  /// User Info e.g username and profile image
  final UserInfo? userInfo;

  /// Time when the story has been created
  final DateTime? createdAt;

  /// Height of the indicator
  final double? indicatorHeight;

  // Background color of indicator
  final Color? indicatorColor;

  // Background color of indicator
  final Color? indicatorValueColor;

  final bool? enableOnHoldHide;

  FlutterStoryView(
      {required this.onComplete,
      required this.onPageChanged,
      this.caption,
      this.onMenuTapListener,
      this.userInfo,
      this.createdAt,
      required this.storyItems,
      this.indicatorHeight,
      this.indicatorColor,
      this.indicatorValueColor,
      this.enableOnHoldHide = true});

  @override
  _FlutterStoryViewState createState() => _FlutterStoryViewState();
}

class _FlutterStoryViewState extends State<FlutterStoryView>
    with TickerProviderStateMixin {
  /// Main Controller
  AnimationController? _animationController;
  VideoPlayerController? _videoController;
  Animation<double>? _animation;

  /// current story item index
  int currentItemIndex = 0;

  /// current progress
  double _progress = 0;

  /// This [_tapDownTime] to indicate how long the story is being hold on finger
  /// so that we can easily find out to resume timer or switch to the next page.
  DateTime? _tapDownTime;

  /// This [_timer] is used to determine if the onTapDown is holded for 200 milliseconds
  /// long or less than this. So that we can find out to go to Next story or
  /// just hide the top and bottom menu on hold.
  Timer? _timer;

  bool _isVideoLoading = false;

  bool _isPaused = false;
  bool isFocus = false;

  @override
  void initState() {
    super.initState();

    /// Start playing the story by calling _playStory method
    _playStory(currentItemIndex);
    // Notify the onPageChanged callback about the current item index
    widget.onPageChanged(currentItemIndex);
  }

  // Start playing the story at the given index
  void _playStory(int index) async {
    /// If story is video
    var story = widget.storyItems[index];

    if (story.type == StoryItemType.video) {
      /// Dispose the previous _videoController (if any) before initializing new one.
      _videoController?.dispose();
      setState(() {
        _isVideoLoading = true; // Set loading to true when video starts loading
      });
      var file = await DownloadUtils.download(story.url, story.id ?? "",
          extension: story.extention);
      print(file);

      // Check if the URL is an asset or a network URL
      bool isAsset = story.url.startsWith('assets/');

      /*  _videoController = isAsset
          ? VideoPlayerController.asset(story.url)
          : VideoPlayerController.networkUrl(Uri.parse(story.url));
       */
      _videoController = VideoPlayerController.file(file!);

      _videoController!
        ..initialize().then((_) {
          setState(() {
            _isVideoLoading = false;
            _isPaused = false;
          });
          _videoController!.play();

          // Limit video duration to 30 seconds
          if (_videoController!.value.duration.inSeconds > 30) {
            _videoController!.setLooping(false); // Disable looping
            Timer(Duration(seconds: 30), () {
              _onAnimationCompleted();
              _videoController!.pause();
            });
          } else {
            _videoController!.setLooping(true); // Enable looping
          }

          Duration clampedDuration =
              _videoController!.value.duration.inSeconds > 30
                  ? Duration(seconds: 30)
                  : _videoController!.value.duration;
          _startAnimation(index, duration: clampedDuration);
        });
    } else {
      _startAnimation(index); // Pass index without video duration
    }
  }

  void _startAnimation(int index, {Duration? duration}) {
    Duration storyDuration =
        duration ?? Duration(seconds: widget.storyItems[index].duration!);

    _animationController = AnimationController(
      vsync: this,
      duration: storyDuration,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController!)
      ..addListener(() {
        setState(() {
          _progress = _animation!.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onAnimationCompleted();
        }
      });

    setState(() {
      _progress = 0.0; // Set progress to 0 before starting the animation
    });

    _animationController!.forward();
  }

  // Handles the completion of the story animation
  void _onAnimationCompleted() {
    if (currentItemIndex == widget.storyItems.length - 1) {
      widget.onComplete();
    } else {
      _videoController?.dispose();
      currentItemIndex++;
      widget.onPageChanged(currentItemIndex);
      setState(() {
        _progress =
            0.0; // Reset progress value to 0 when the story automatically advances
      });
      _playStory(currentItemIndex);
    }
  }

  // Handles tap action to go to the next story item
  void _onTapNext() {
    // To prevent moving to the next story if the video is still loading
    if (_isVideoLoading) return;

    if (currentItemIndex == widget.storyItems.length - 1) {
      widget.onComplete();
    } else {
      _videoController?.dispose();
      currentItemIndex++;
      widget.onPageChanged(currentItemIndex);
      _animationController!.dispose();
      setState(() {
        _progress = 0.0; // Reset progress value to 0 when tapping next
      });
      _playStory(currentItemIndex);
    }
  }

  // Handles tap action to go to the previous story item
  void _onTapPrevious() {
    if (currentItemIndex == 0) {
      // You can perform something here :)
    } else {
      _videoController?.dispose();

      currentItemIndex--;
      widget.onPageChanged(currentItemIndex);
      _animationController!.dispose();
      setState(() {
        _progress = 0.0; // Reset progress value to 0 when tapping next
      });
      _playStory(currentItemIndex);
    }
  }

  // Pause the story timer
  void _pauseTimer() {
    _animationController!.stop();
    _videoController?.pause();
    setState(() {});
  }

  // Resume the story timer
  void _resumeTimer() {
    _animationController!.forward();
    _videoController?.play();
    setState(() {});
  }

  // Dispose of the animation controller when the widget is disposed
  @override
  void dispose() {
    _animationController?.dispose();
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var story = widget.storyItems[currentItemIndex];
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
          child: Container(
        color: Colors.black,
        child: GestureDetector(
          child: Stack(
            children: [
              /// All story items mapped in the Stack widget
              Stack(
                children: List.generate(
                  widget.storyItems.length,
                  (index) {
                    var story = widget.storyItems[index];
                    return Visibility(
                        visible: currentItemIndex == index,
                        maintainState: true,
                        child: _storyItem(story));
                  },
                ),
              ),

              /// Story indicator which plays with timer, progress and total story Items
              /// check out widget in widgets dir.
              ///
              ///
              ///

              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.40),
                        Colors.transparent,
                      ])),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedOpacity(
                        duration: Duration(milliseconds: 200),
                        opacity: widget.enableOnHoldHide == false
                            ? 1
                            : !_isPaused
                                ? 1
                                : 0,
                        child: StoryIndicator(
                          storyItemsLen: widget.storyItems.length,
                          currentItemIndex: currentItemIndex, // Add this
                          progress: _progress,
                          indicatorColor: widget.indicatorColor,
                          indicatorHeight: widget.indicatorHeight,
                          indicatorValueColor: widget.indicatorValueColor,
                        ),
                      ),
                      AnimatedOpacity(
                        duration: Duration(milliseconds: 200),
                        opacity: widget.enableOnHoldHide == false
                            ? 1
                            : !_isPaused
                                ? 1
                                : 0,
                        child: Container(
                          height: 100,
                          padding: EdgeInsets.only(left: 0, right: 0, top: 10),
                          // color: Colors.black,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 5,
                              ),
                              SizedBox(
                                height: 5,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                      onTap: widget.onComplete,
                                      child: Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                      )),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Container(
                                    width: 45,
                                    height: 45,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: CachedNetworkImage(
                                          imageUrl: widget
                                                      .userInfo!.profileUrl !=
                                                  null
                                              ? widget.userInfo!.profileUrl!
                                              : "https://images.unsplash.com/photo-1552058544-f2b08422138a?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=699&q=80",
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: Container(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${widget.userInfo!.username != null ? widget.userInfo!.username! : "John Doe"}",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white),
                                          ),
                                          SizedBox(
                                            height: 2,
                                          ),
                                          if (story.time != null)
                                            Text(
                                              "${DateFormat.jm().format(story.time!)}",
                                              style:
                                                  TextStyle(color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (story.onClick != null)
                                    GestureDetector(
                                        onTap: () {
                                          story.onClick?.call();
                                        },
                                        child: Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                        ))
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),

              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if ((story.caption?.isNotEmpty ?? false))
                      GestureDetector(
                        onTap: () async {
                          /*   await showTextAnswerDialog(
                        context: context, title: "", keyword: "sas"); */
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.50)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${currentItemIndex == 0 ? story.caption ?? "" : ""}",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.storyItems[currentItemIndex].showControls)
                      GestureDetector(
                        onTap: () async {
                          /*    await showTextAnswerDialog(
                      context: context, title: "", keyword: "sas"); */
                        },
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          margin: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 10),
                              Expanded(
                                  child: Focus(
                                child: TextField(
                                  controller: controller,
                                  decoration:
                                      InputDecoration(border: InputBorder.none),
                                  style: TextStyle(color: Colors.white),
                                ),
                                onFocusChange: (hasFocus) {
                                  isFocus = hasFocus;
                                  if (hasFocus) {
                                    _animationController?.stop();
                                  } else
                                    _animationController?.repeat();
                                },
                              )),
                              SizedBox(width: 10),
                              GestureDetector(
                                  onTap: () {
                                    if (story.isLiked ?? false) {
                                      return;
                                    }
                                    story.onLikeSubmitted?.call();
                                  },
                                  child: Icon(
                                    Icons.favorite,
                                    color: (story.isLiked ?? false)
                                        ? Colors.yellow
                                        : Colors.white,
                                  )),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    if (controller.text.isEmpty) return;
                                    story.onReplySubmitted
                                        ?.call(controller.text);
                                    controller.text = "";
                                  },
                                  child: Icon(
                                    Icons.send,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    /* Column(
                children: [
                  Icon(Icons.keyboard_arrow_up),
                  SizedBox(
                    height: 3,
                  ),
                  Text("Replay"),
                ],
              ),*/
                    ,
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  // Creates a single story item widget
  _storyItem(StoryItem story) {
    TextEditingController controller = TextEditingController();
    return Column(
      children: [
        /*  AnimatedOpacity(
          duration: Duration(milliseconds: 200),
          opacity: widget.enableOnHoldHide == false
              ? 1
              : !_isPaused
                  ? 1
                  : 0,
          child: Container(
            height: 100,
            padding: EdgeInsets.only(left: 0, right: 0, top: 40),
            color: Colors.black,
            child: Column(
              children: [
                SizedBox(
                  height: 5,
                ),
                SizedBox(
                  height: 5,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                        onTap: widget.onComplete,
                        child: Icon(Icons.arrow_back)),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: 45,
                      height: 45,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: CachedNetworkImage(
                            imageUrl: widget.userInfo!.profileUrl != null
                                ? widget.userInfo!.profileUrl!
                                : "https://images.unsplash.com/photo-1552058544-f2b08422138a?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=699&q=80",
                            fit: BoxFit.cover),
                      ),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Container(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${widget.userInfo!.username != null ? widget.userInfo!.username! : "John Doe"}",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            SizedBox(
                              height: 2,
                            ),
                            if (story.time != null)
                              Text(
                                "${DateFormat.jm().format(story.time!)}",
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (story.onClick != null)
                      GestureDetector(
                          onTap: () {
                            story.onClick?.call();
                          },
                          child: Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ))
                  ],
                ),
              ],
            ),
          ),
        ),
        */
        Expanded(
          child: Container(
            child: Stack(
              children: [
                Visibility(
                  visible:
                      currentItemIndex == widget.storyItems.indexOf(story) &&
                          story.type == StoryItemType.video &&
                          (_videoController == null ||
                              !_videoController!.value.isInitialized) &&
                          _isVideoLoading,
                  child: Container(
                    color: Colors.grey[600],
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),

                _switchStoryItemIsVideoOrImage(
                  story.url,
                  type: story.type,
                  controller: _videoController, // Pass the controller
                ),

                // Next story area
                Align(
                  alignment: Alignment.centerRight,
                  heightFactor: 1,
                  child: GestureDetector(
                    onTapDown: (details) {
                      _tapDownTime = DateTime.now();
                      _timer = Timer(Duration(milliseconds: 200), () {
                        _timer = null;
                        if (_tapDownTime != null && _isVideoLoading == false) {
                          final elapsedTime = DateTime.now()
                              .difference(_tapDownTime!)
                              .inMilliseconds;
                          if (elapsedTime >= 200) {
                            setState(() => _isPaused = true);
                            _pauseTimer();
                          } else {
                            /// Do nothing if the onTapDown is tapped less than 200 milliseconds
                          }
                        }
                      });
                    },
                    onTapCancel: () {
                      _resumeTimer();
                      setState(() => _isPaused = false);
                    },
                    onTapUp: (details) {
                      if (_tapDownTime != null) {
                        final elapsedTime = DateTime.now()
                            .difference(_tapDownTime!)
                            .inMilliseconds;
                        if (elapsedTime > 200) {
                          _resumeTimer();
                          setState(() => _isPaused = false);
                        } else {
                          _onTapNext();
                        }
                        _tapDownTime = null;
                      }
                    },
                  ),
                ),

                // Previous story area
                Align(
                  alignment: Alignment.centerLeft,
                  heightFactor: 1,
                  child: SizedBox(
                    width: 70,
                    child: GestureDetector(
                      onTapDown: (details) {
                        _tapDownTime = DateTime.now();
                        _timer = Timer(Duration(milliseconds: 200), () {
                          _timer = null;
                          if (_tapDownTime != null &&
                              _isVideoLoading == false) {
                            final elapsedTime = DateTime.now()
                                .difference(_tapDownTime!)
                                .inMilliseconds;
                            if (elapsedTime >= 200) {
                              setState(() => _isPaused = true);
                              _pauseTimer();
                            } else {
                              /// Do nothing if the onTapDown is tapped less than 200 milliseconds
                            }
                          }
                        });
                      },
                      onTapCancel: () {
                        _resumeTimer();
                        setState(() => _isPaused = false);
                      },
                      onTapUp: (details) {
                        if (_tapDownTime != null) {
                          final elapsedTime = DateTime.now()
                              .difference(_tapDownTime!)
                              .inMilliseconds;
                          if (elapsedTime > 200) {
                            _resumeTimer();
                            setState(() => _isPaused = false);
                          } else {
                            _onTapPrevious();
                          }
                          _tapDownTime = null;
                        }
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  _switchStoryItemIsVideoOrImage(
    String url, {
    required String type,
    VideoPlayerController? controller,
  }) {
    bool isAsset = url.startsWith('assets/');
    switch (type) {
      case StoryItemType.image:
        return StoryImage.url(url, isAsset: isAsset);
      case StoryItemType.video:
        return StoryVideo.url(url, controller);
    }
  }
}
