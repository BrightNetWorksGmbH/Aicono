import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseEvent {}

class CreateVerseRequested extends VerseEvent {
  final CreateVerseRequest request;

  CreateVerseRequested(this.request);
}

class LoadAllVersesRequested extends VerseEvent {}
