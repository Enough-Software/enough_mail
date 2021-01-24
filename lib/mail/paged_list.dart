class PagedList<T> {
  final int pageSize;
  final int size;
  final int currentPage;
  final List<T> elements;

  const PagedList(this.pageSize, this.size, this.currentPage, this.elements);

  const PagedList.empty(
      {this.pageSize = 0, this.size = 0, this.currentPage = 0, this.elements});
}
