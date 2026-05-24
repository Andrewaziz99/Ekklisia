// lib/features/books/cubit/books_state.dart
import 'package:equatable/equatable.dart';

import '../../../data/models/book_model.dart';

enum BooksStatus { initial, loading, loaded, error }

class BooksState extends Equatable {
  const BooksState({
    this.status = BooksStatus.initial,
    this.books = const [],
    this.filteredBooks = const [],
    this.selectedCategory,
    this.searchQuery = '',
    this.errorMessage,
  });

  final BooksStatus status;
  final List<BookModel> books;
  final List<BookModel> filteredBooks;
  final String? selectedCategory;
  final String searchQuery;
  final String? errorMessage;

  bool get isLoading => status == BooksStatus.loading;
  bool get hasError => status == BooksStatus.error;
  bool get isEmpty => status == BooksStatus.loaded && filteredBooks.isEmpty;

  BooksState copyWith({
    BooksStatus? status,
    List<BookModel>? books,
    List<BookModel>? filteredBooks,
    String? selectedCategory,
    String? searchQuery,
    String? errorMessage,
  }) => BooksState(
    status: status ?? this.status,
    books: books ?? this.books,
    filteredBooks: filteredBooks ?? this.filteredBooks,
    selectedCategory: selectedCategory,
    searchQuery: searchQuery ?? this.searchQuery,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    books,
    filteredBooks,
    selectedCategory,
    searchQuery,
    errorMessage,
  ];
}
