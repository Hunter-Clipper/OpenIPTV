/// The saved category order after moving [category] by [delta] places
/// (-1 up, +1 down) within the [visible] list the user is looking at.
/// Categories the user can't see right now (hidden, locked) keep their
/// saved place after the visible ones. Returns [saved] unchanged if the
/// move isn't possible.
List<String> reorderedCategories(
  List<String> visible,
  String category,
  int delta,
  List<String> saved,
) {
  final from = visible.indexOf(category);
  final to = from + delta;
  if (from < 0 || to < 0 || to >= visible.length) return saved;
  final moved = [...visible];
  moved.insert(to, moved.removeAt(from));
  return [...moved, ...saved.where((c) => !moved.contains(c))];
}
