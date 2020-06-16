class Tree<T> {
  TreeElement<T> root;

  Tree(T rootValue) {
    root = TreeElement(rootValue, null);
  }

  @override
  String toString() {
    return root.toString();
  }

  /// Lists all leafs of this tree
  /// Specify how to detect the leafs with [isLeaf].
  List<T> flatten(bool Function(T element) isLeaf) {
    var leafs = <T>[];
    _addLeafs(root, isLeaf, leafs);
    return leafs;
  }

  void _addLeafs(
      TreeElement<T> root, bool Function(T element) isLeaf, List<T> leafs) {
    for (var child in root.children) {
      if (isLeaf == null || isLeaf(child.value)) {
        leafs.add(child.value);
      }
      if (child.children != null) {
        _addLeafs(child, isLeaf, leafs);
      }
    }
  }

  void populateFromList(List<T> elements, T Function(T child) getParent) {
    for (var element in elements) {
      var parent = getParent(element);
      if (parent == null) {
        root.addChild(element);
      } else {
        _addChildToParent(element, parent, getParent);
      }
    }
  }

  TreeElement<T> _addChildToParent(
      T child, T parent, T Function(T child) getParent) {
    var treeElement = locate(parent);
    if (treeElement == null) {
      var grandParent = getParent(parent);
      if (grandParent == null) {
        // add new tree element to root:
        treeElement = root.addChild(parent);
      } else {
        treeElement = _addChildToParent(parent, grandParent, getParent);
      }
    }
    return treeElement.addChild(child);
  }

  TreeElement<T> locate(T value) {
    return _locate(value, root);
  }

  TreeElement<T> _locate(T value, TreeElement<T> root) {
    for (var child in root.children) {
      if (child.value == value) {
        return child;
      }
      if (child.hasChildren) {
        var result = _locate(value, child);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }
}

class TreeElement<T> {
  T value;
  List<TreeElement<T>> children;
  bool get hasChildren => children != null && children.isNotEmpty;
  TreeElement<T> parent;

  TreeElement(this.value, this.parent);

  TreeElement<T> addChild(T child) {
    children ??= <TreeElement<T>>[];
    var element = TreeElement(child, this);
    children.add(element);
    return element;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
  }

  void render(StringBuffer buffer, [String padding = '']) {
    buffer..write(padding)..write(value)..write('\n');
    if (children != null) {
      buffer..write(padding)..write('[\n');
      for (var child in children) {
        child.render(buffer, padding + ' ');
      }
      buffer..write(padding)..write(']\n');
    }
  }
}
