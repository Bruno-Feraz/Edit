/// Stack undo/redo leggero: tiene snapshot JSON della timeline, non i media.
class UndoHistory {
  UndoHistory({this.maxDepth = 40});

  final int maxDepth;
  final List<String> _undo = [];
  final List<String> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void push(String snapshot) {
    _undo.add(snapshot);
    if (_undo.length > maxDepth) {
      _undo.removeAt(0);
    }
    _redo.clear();
  }

  String? undo(String current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    return _undo.removeLast();
  }

  String? redo(String current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
