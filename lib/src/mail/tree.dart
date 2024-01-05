/// Contains a tree like structure
class Tree<T> {
  /// Creates a new tree with the given root value
  Tree(T rootValue) : root = TreeElement(rootValue, null);

  /// The root element
  final TreeElement<T> root;

  @override
  String toString() => root.toString();

  /// Lists all leafs of this tree
  /// Specify how to detect the leafs with [isLeaf].
  List<T> flatten(bool Function(T element) isLeaf) {
    final leafs = <T>[];
    _addLeafs(root, isLeaf, leafs);

    return leafs;
  }

  void _addLeafs(
    TreeElement<T> root,
    bool Function(T element) isLeaf,
    List<T> leafs,
  ) {
    for (final child in root.children ?? []) {
      if (isLeaf(child.value)) {
        leafs.add(child.value);
      }
      if (child.children != null) {
        _addLeafs(child, isLeaf, leafs);
      }
    }
  }

  /// Populates this tree from the given list of [elements]
  void populateFromList(List<T> elements, T Function(T child) getParent) {
    for (final element in elements) {
      final parent = getParent(element);
      if (parent == null) {
        root.addChild(element);
      } else {
        _addChildToParent(element, parent, getParent);
      }
    }
  }

  TreeElement<T> _addChildToParent(
    T child,
    T parent,
    T Function(T child) getParent,
  ) {
    var treeElement = locate(parent);
    if (treeElement == null) {
      final grandParent = getParent(parent);
      treeElement = grandParent == null
          ? root.addChild(parent)
          : _addChildToParent(parent, grandParent, getParent);
    }

    return treeElement.addChild(child);
  }

  /// Finds the tree element for the given [value].
  TreeElement<T>? locate(T value) => _locate(value, root);

  /// Locates a specific value in this tree
  T? firstWhereOrNull(bool Function(T value) test) =>
      _firstWhereOrNullFor(test, root);

  T? _firstWhereOrNullFor(bool Function(T value) test, TreeElement<T> element) {
    if (test(element.value)) {
      return element.value;
    }
    final children = element.children;
    if (children != null) {
      for (final child in children) {
        final result = _firstWhereOrNullFor(test, child);
        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  TreeElement<T>? _locate(T value, TreeElement<T> root) {
    final children = root.children;
    if (children == null) {
      return null;
    }
    for (final child in children) {
      if (child.value == value) {
        return child;
      }
      if (child.hasChildren) {
        final result = _locate(value, child);
        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }
}

/// An Element in a Tree
class TreeElement<T> {
  /// Creates a new tree element
  TreeElement(this.value, this.parent);

  /// The value of the tree
  final T value;

  /// Any sub nodes of this tree element
  List<TreeElement<T>>? children;

  /// Checks of this tree element has children
  bool get hasChildren {
    final children = this.children;

    return children != null && children.isNotEmpty;
  }

  /// The parent of this element, if known
  TreeElement<T>? parent;

  /// Adds the [child] to this element
  TreeElement<T> addChild(T child) {
    children ??= <TreeElement<T>>[];
    final element = TreeElement(child, this);
    children?.add(element);

    return element;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    render(buffer);

    return buffer.toString();
  }

  /// Renders this tree element into the given [buffer]
  void render(StringBuffer buffer, [String padding = '']) {
    buffer
      ..write(padding)
      ..write(value)
      ..write('\n');
    if (children != null) {
      buffer
        ..write(padding)
        ..write('[\n');
      final childPadding = '$padding ';
      for (final child in children ?? []) {
        child.render(buffer, childPadding);
      }
      buffer
        ..write(padding)
        ..write(']\n');
    }
  }
}
