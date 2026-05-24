import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/book_model.dart';
import '../../../data/repositories/books_repository.dart';
import 'books_state.dart';

class BooksCubit extends Cubit<BooksState> {
  BooksCubit(this._repository) : super(const BooksState());

  final BooksRepository _repository;
  StreamSubscription<List<BookModel>>? _booksSubscription;

  // ── Subscribe ──────────────────────────────────────────────────────────

  void watchBooks({String? category}) {
    emit(
      state.copyWith(status: BooksStatus.loading, selectedCategory: category),
    );

    _booksSubscription?.cancel();
    _booksSubscription = _repository
        .watchBooks(category: category)
        .listen(
          (books) {
            final filtered = _applyFilters(books, state.searchQuery, category);
            emit(
              state.copyWith(
                status: BooksStatus.loaded,
                books: books,
                filteredBooks: filtered,
                selectedCategory: category,
              ),
            );
          },
          onError: (e) {
            emit(
              state.copyWith(
                status: BooksStatus.error,
                errorMessage: e.toString(),
              ),
            );
          },
        );
  }

  // ── Category Filter ────────────────────────────────────────────────────

  void filterByCategory(String? category) {
    final filtered = _applyFilters(state.books, state.searchQuery, category);
    emit(state.copyWith(filteredBooks: filtered, selectedCategory: category));
  }

  // ── Search ─────────────────────────────────────────────────────────────

  void search(String query) {
    final filtered = _applyFilters(state.books, query, state.selectedCategory);
    emit(state.copyWith(filteredBooks: filtered, searchQuery: query));
  }

  void clearSearch() => search('');

  // ── Internal Filter Logic ──────────────────────────────────────────────

  List<BookModel> _applyFilters(
    List<BookModel> books,
    String query,
    String? category,
  ) {
    var result = books;

    if (category != null && category.isNotEmpty) {
      result = result.where((b) => b.category == category).toList();
    }

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((b) {
        return b.titleAr.toLowerCase().contains(q) ||
            b.titleCop.toLowerCase().contains(q) ||
            b.titleEl.toLowerCase().contains(q) ||
            b.descriptionAr.toLowerCase().contains(q) ||
            b.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return result;
  }

  @override
  Future<void> close() {
    _booksSubscription?.cancel();
    return super.close();
  }
}
