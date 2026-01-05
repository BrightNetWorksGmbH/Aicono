import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseCreateEvent {}

class CreateVerseRequested extends VerseCreateEvent {
  final CreateVerseRequest request;

  CreateVerseRequested(this.request);
}
