class StoryItemType {
  static const String image = "image";
  static const String video = "video";
}

/// Represents a story with a URL, viewers and type.
class StoryItem {
  /// The URL of the story.
  final String url;

  /// The viewers of the story.
  final List<dynamic>? viewers;
  final String? extention;

  /// The type of the story.
  final String type;

  // Add a duration property for each StoryItem
  final int? duration;
  final String? id;
  final bool? isLiked;

  /// Constructs a new [StoryItem] instance with the given [url], [viewers], [type] and [duration].
  const StoryItem(
      {required this.url,
      required this.id,
      required this.isLiked,
      required this.extention,
      this.viewers,
      required this.type,
      this.duration = 3,
      this.caption,
      this.time,
      required this.showControls,
      this.onClick,
      this.onReplySubmitted,
      this.onLikeSubmitted});

  /// Converts this [StoryItem] instance to a JSON format.
  Map<String, dynamic> toJson() =>
      {"url": url, "viewers": viewers, "type": type, "duration": duration};

  /// Converts this [StoryItem] instance to a list of [StoryItem].
  List<StoryItem> toList() => List<StoryItem>.of([this]);

  final String? caption;
  final DateTime? time;
  final Function? onClick;
  final Function(String text)? onReplySubmitted;
  final Function()? onLikeSubmitted;
  final bool showControls;
}
