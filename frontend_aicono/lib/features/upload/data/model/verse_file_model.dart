// data/models/verse_file_model.dart
import '../../domain/entities/verse_file.dart';

class VerseFileModel extends VerseFile {
  VerseFileModel({
    required super.verseId,
    required super.channelId,
    required super.name,
    required super.originalFilename,
    required super.fileType,
    required super.fileExtension,
    required super.fileSize,
    required super.fileUrl,
    required super.thumbnailUrl,
    required super.folderPath,
    required super.fileMetadata,
    required super.metadataData,
  });
  // Create model from domain entity
  factory VerseFileModel.fromEntity(VerseFile entity) {
    return VerseFileModel(
      verseId: entity.verseId,
      channelId: entity.channelId,
      name: entity.name,
      originalFilename: entity.originalFilename,
      fileType: entity.fileType,
      fileExtension: entity.fileExtension,
      fileSize: entity.fileSize,
      fileUrl: entity.fileUrl,
      thumbnailUrl: entity.thumbnailUrl,
      folderPath: entity.folderPath,
      fileMetadata: entity.fileMetadata,
      metadataData: entity.metadataData,
    );
  }

  factory VerseFileModel.fromJson(Map<String, dynamic> json) {
    return VerseFileModel(
      verseId: json['verse_id'],
      channelId: json['channel_id'],
      name: json['name'],
      originalFilename: json['original_filename'],
      fileType: json['file_type'],
      fileExtension: json['file_extension'],
      fileSize: json['file_size'],
      fileUrl: json['file_url'],
      thumbnailUrl: json['thumbnail_url'],
      folderPath: json['folder_path'],
      fileMetadata: FileMetadata(
        dimensions: Dimensions(
          width: json['file_metadata']['dimensions']['width'],
          height: json['file_metadata']['dimensions']['height'],
        ),
        resolution: Resolution(dpi: json['file_metadata']['resolution']['dpi']),
        colorMode: json['file_metadata']['color_mode'],
      ),
      metadataData: MetadataData(
        imageFileInfo: ImageFileInfo(
          title: json['metadata_data']['image_file_info']['title'],
          altText: json['metadata_data']['image_file_info']['alt_text'],
          description: json['metadata_data']['image_file_info']['description'],
          tags: List<String>.from(
            json['metadata_data']['image_file_info']['tags'],
          ),
          keywords: List<String>.from(
            json['metadata_data']['image_file_info']['keywords'],
          ),
          subjectName: json['metadata_data']['image_file_info']['subject_name'],
          location: json['metadata_data']['image_file_info']['location'],
          dateTaken: json['metadata_data']['image_file_info']['date_taken'],
        ),
        copyrightInfo: CopyrightInfo(
          status: json['metadata_data']['copyright_info']['status'],
          holder: json['metadata_data']['copyright_info']['holder'],
          year: json['metadata_data']['copyright_info']['year'],
          notice: json['metadata_data']['copyright_info']['notice'],
          licenseType: json['metadata_data']['copyright_info']['license_type'],
          usageRights: json['metadata_data']['copyright_info']['usage_rights'],
        ),
        creatorUsage: CreatorUsage(
          creatorType: json['metadata_data']['creator_usage']['creator_type'],
          isBrightNetworksCreator:
              json['metadata_data']['creator_usage']['is_bright_networks_creator'],
          creatorName: json['metadata_data']['creator_usage']['creator_name'],
          creatorContact: CreatorContact(
            email:
                json['metadata_data']['creator_usage']['creator_contact']['email'],
            website:
                json['metadata_data']['creator_usage']['creator_contact']['website'],
          ),
          attributionRequired:
              json['metadata_data']['creator_usage']['attribution_required'],
          commercialUseAllowed:
              json['metadata_data']['creator_usage']['commercial_use_allowed'],
          modificationAllowed:
              json['metadata_data']['creator_usage']['modification_allowed'],
        ),
        imageDescription: ImageDescription(
          description:
              json['metadata_data']['image_description']['description'],
          generatedByAi:
              json['metadata_data']['image_description']['generated_by_ai'],
          manuallyEntered:
              json['metadata_data']['image_description']['manually_entered'],
          accessibilityNotes:
              json['metadata_data']['image_description']['accessibility_notes'],
          contentWarning:
              json['metadata_data']['image_description']['content_warning'],
        ),
        searchKeywords: SearchKeywords(
          seoKeywords: List<String>.from(
            json['metadata_data']['search_keywords']['seo_keywords'],
          ),
          verseSearchKeyword: List<String>.from(
            json['metadata_data']['search_keywords']['verse_search_keyword'],
          ),
          categoryTags: List<String>.from(
            json['metadata_data']['search_keywords']['category_tags'],
          ),
          industryTags: List<String>.from(
            json['metadata_data']['search_keywords']['industry_tags'],
          ),
          generatedByAi:
              json['metadata_data']['search_keywords']['generated_by_ai'],
          manuallyEntered:
              json['metadata_data']['search_keywords']['manually_entered'],
        ),
        internalNotes: InternalNotes(
          notes: json['metadata_data']['internal_notes']['notes'],
          priority: json['metadata_data']['internal_notes']['priority'],
          reviewRequired:
              json['metadata_data']['internal_notes']['review_required'],
          reviewerNotes:
              json['metadata_data']['internal_notes']['reviewer_notes'],
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "verse_id": verseId,
      "channel_id": channelId,
      "name": originalFilename,
      "original_filename": originalFilename,
      "file_type": fileType,
      "file_extension": fileExtension,
      "file_size": fileSize,
      "file_url": fileUrl,
      "thumbnail_url": thumbnailUrl,
      "folder_path": folderPath,
      "file_metadata": {
        "dimensions": {
          "width": fileMetadata.dimensions.width,
          "height": fileMetadata.dimensions.height,
        },
        "resolution": {"dpi": fileMetadata.resolution.dpi},
        "color_mode": fileMetadata.colorMode,
      },
      "metadata_data": {
        "image_file_info": {
          "title": metadataData.imageFileInfo.title,
          "alt_text": metadataData.imageFileInfo.altText,
          "description": metadataData.imageFileInfo.description,
          "tags": metadataData.imageFileInfo.tags,
          "keywords": metadataData.imageFileInfo.keywords,
          "subject_name": metadataData.imageFileInfo.subjectName,
          "location": metadataData.imageFileInfo.location,
          "date_taken": metadataData.imageFileInfo.dateTaken,
        },
        "copyright_info": {
          "status": metadataData.copyrightInfo.status,
          "holder": metadataData.copyrightInfo.holder,
          "year": metadataData.copyrightInfo.year,
          "notice": metadataData.copyrightInfo.notice,
          "license_type": metadataData.copyrightInfo.licenseType,
          "usage_rights": metadataData.copyrightInfo.usageRights,
        },
        "creator_usage": {
          "creator_type": metadataData.creatorUsage.creatorType,
          "is_bright_networks_creator":
              metadataData.creatorUsage.isBrightNetworksCreator,
          "creator_name": metadataData.creatorUsage.creatorName,
          "creator_contact": {
            "email": metadataData.creatorUsage.creatorContact.email,
            "website": metadataData.creatorUsage.creatorContact.website,
          },
          "attribution_required": metadataData.creatorUsage.attributionRequired,
          "commercial_use_allowed":
              metadataData.creatorUsage.commercialUseAllowed,
          "modification_allowed": metadataData.creatorUsage.modificationAllowed,
        },
        "image_description": {
          "description": metadataData.imageDescription.description,
          "generated_by_ai": metadataData.imageDescription.generatedByAi,
          "manually_entered": metadataData.imageDescription.manuallyEntered,
          "accessibility_notes":
              metadataData.imageDescription.accessibilityNotes,
          "content_warning": metadataData.imageDescription.contentWarning,
        },
        "search_keywords": {
          "seo_keywords": metadataData.searchKeywords.seoKeywords,
          "verse_search_keyword":
              metadataData.searchKeywords.verseSearchKeyword,
          "category_tags": metadataData.searchKeywords.categoryTags,
          "industry_tags": metadataData.searchKeywords.industryTags,
          "generated_by_ai": metadataData.searchKeywords.generatedByAi,
          "manually_entered": metadataData.searchKeywords.manuallyEntered,
        },
        "internal_notes": {
          "notes": metadataData.internalNotes.notes,
          "priority": metadataData.internalNotes.priority,
          "review_required": metadataData.internalNotes.reviewRequired,
          "reviewer_notes": metadataData.internalNotes.reviewerNotes,
        },
      },
    };
  }
}
