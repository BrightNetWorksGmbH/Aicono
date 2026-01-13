// domain/entities/verse_file.dart

class VerseFile {
  final String verseId;
  final String channelId;
  final String name;
  final String originalFilename;
  final String fileType;
  final String fileExtension;
  final int fileSize;
  final String fileUrl;
  final String thumbnailUrl;
  final String folderPath;
  final FileMetadata fileMetadata;
  final MetadataData metadataData;

  VerseFile({
    required this.verseId,
    required this.channelId,
    required this.name,
    required this.originalFilename,
    required this.fileType,
    required this.fileExtension,
    required this.fileSize,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.folderPath,
    required this.fileMetadata,
    required this.metadataData,
  });

  VerseFile copyWith({
    String? verseId,
    String? channelId,
    String? name,
    String? originalFilename,
    String? fileType,
    String? fileExtension,
    int? fileSize,
    String? fileUrl,
    String? thumbnailUrl,
    String? folderPath,
    FileMetadata? fileMetadata,
    MetadataData? metadataData,
  }) {
    return VerseFile(
      verseId: verseId ?? this.verseId,
      channelId: channelId ?? this.channelId,
      name: name ?? this.name,
      originalFilename: originalFilename ?? this.originalFilename,
      fileType: fileType ?? this.fileType,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSize: fileSize ?? this.fileSize,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      folderPath: folderPath ?? this.folderPath,
      fileMetadata: fileMetadata ?? this.fileMetadata,
      metadataData: metadataData ?? this.metadataData,
    );
  }
}

class FileMetadata {
  final Dimensions dimensions;
  final Resolution resolution;
  final String colorMode;

  FileMetadata({
    required this.dimensions,
    required this.resolution,
    required this.colorMode,
  });

  FileMetadata copyWith({
    Dimensions? dimensions,
    Resolution? resolution,
    String? colorMode,
  }) {
    return FileMetadata(
      dimensions: dimensions ?? this.dimensions,
      resolution: resolution ?? this.resolution,
      colorMode: colorMode ?? this.colorMode,
    );
  }
}

class Dimensions {
  final int width;
  final int height;

  Dimensions({required this.width, required this.height});

  Dimensions copyWith({int? width, int? height}) {
    return Dimensions(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class Resolution {
  final int dpi;
  Resolution({required this.dpi});

  Resolution copyWith({int? dpi}) {
    return Resolution(dpi: dpi ?? this.dpi);
  }
}

class MetadataData {
  final ImageFileInfo imageFileInfo;
  final CopyrightInfo copyrightInfo;
  final CreatorUsage creatorUsage;
  final ImageDescription imageDescription;
  final SearchKeywords searchKeywords;
  final InternalNotes internalNotes;

  MetadataData({
    required this.imageFileInfo,
    required this.copyrightInfo,
    required this.creatorUsage,
    required this.imageDescription,
    required this.searchKeywords,
    required this.internalNotes,
  });

  MetadataData copyWith({
    ImageFileInfo? imageFileInfo,
    CopyrightInfo? copyrightInfo,
    CreatorUsage? creatorUsage,
    ImageDescription? imageDescription,
    SearchKeywords? searchKeywords,
    InternalNotes? internalNotes,
  }) {
    return MetadataData(
      imageFileInfo: imageFileInfo ?? this.imageFileInfo,
      copyrightInfo: copyrightInfo ?? this.copyrightInfo,
      creatorUsage: creatorUsage ?? this.creatorUsage,
      imageDescription: imageDescription ?? this.imageDescription,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      internalNotes: internalNotes ?? this.internalNotes,
    );
  }
}

class ImageFileInfo {
  final String title;
  final String altText;
  final String description;
  final List<String> tags;
  final List<String> keywords;
  final String subjectName;
  final String location;
  final String dateTaken;

  ImageFileInfo({
    required this.title,
    required this.altText,
    required this.description,
    required this.tags,
    required this.keywords,
    required this.subjectName,
    required this.location,
    required this.dateTaken,
  });

  ImageFileInfo copyWith({
    String? title,
    String? altText,
    String? description,
    List<String>? tags,
    List<String>? keywords,
    String? subjectName,
    String? location,
    String? dateTaken,
  }) {
    return ImageFileInfo(
      title: title ?? this.title,
      altText: altText ?? this.altText,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      keywords: keywords ?? this.keywords,
      subjectName: subjectName ?? this.subjectName,
      location: location ?? this.location,
      dateTaken: dateTaken ?? this.dateTaken,
    );
  }
}

class CopyrightInfo {
  final String status;
  final String holder;
  final int year;
  final String notice;
  final String licenseType;
  final String usageRights;

  CopyrightInfo({
    required this.status,
    required this.holder,
    required this.year,
    required this.notice,
    required this.licenseType,
    required this.usageRights,
  });

  CopyrightInfo copyWith({
    String? status,
    String? holder,
    int? year,
    String? notice,
    String? licenseType,
    String? usageRights,
  }) {
    return CopyrightInfo(
      status: status ?? this.status,
      holder: holder ?? this.holder,
      year: year ?? this.year,
      notice: notice ?? this.notice,
      licenseType: licenseType ?? this.licenseType,
      usageRights: usageRights ?? this.usageRights,
    );
  }
}

class CreatorUsage {
  final String creatorType;
  final bool isBrightNetworksCreator;
  final String creatorName;
  final CreatorContact creatorContact;
  final bool attributionRequired;
  final bool commercialUseAllowed;
  final bool modificationAllowed;

  CreatorUsage({
    required this.creatorType,
    required this.isBrightNetworksCreator,
    required this.creatorName,
    required this.creatorContact,
    required this.attributionRequired,
    required this.commercialUseAllowed,
    required this.modificationAllowed,
  });

  CreatorUsage copyWith({
    String? creatorType,
    bool? isBrightNetworksCreator,
    String? creatorName,
    CreatorContact? creatorContact,
    bool? attributionRequired,
    bool? commercialUseAllowed,
    bool? modificationAllowed,
  }) {
    return CreatorUsage(
      creatorType: creatorType ?? this.creatorType,
      isBrightNetworksCreator:
          isBrightNetworksCreator ?? this.isBrightNetworksCreator,
      creatorName: creatorName ?? this.creatorName,
      creatorContact: creatorContact ?? this.creatorContact,
      attributionRequired: attributionRequired ?? this.attributionRequired,
      commercialUseAllowed: commercialUseAllowed ?? this.commercialUseAllowed,
      modificationAllowed: modificationAllowed ?? this.modificationAllowed,
    );
  }
}

class CreatorContact {
  final String email;
  final String website;

  CreatorContact({required this.email, required this.website});

  CreatorContact copyWith({String? email, String? website}) {
    return CreatorContact(
      email: email ?? this.email,
      website: website ?? this.website,
    );
  }
}

class ImageDescription {
  final String description;
  final bool generatedByAi;
  final bool manuallyEntered;
  final String accessibilityNotes;
  final String? contentWarning;

  ImageDescription({
    required this.description,
    required this.generatedByAi,
    required this.manuallyEntered,
    required this.accessibilityNotes,
    this.contentWarning,
  });

  ImageDescription copyWith({
    String? description,
    bool? generatedByAi,
    bool? manuallyEntered,
    String? accessibilityNotes,
    String? contentWarning,
  }) {
    return ImageDescription(
      description: description ?? this.description,
      generatedByAi: generatedByAi ?? this.generatedByAi,
      manuallyEntered: manuallyEntered ?? this.manuallyEntered,
      accessibilityNotes: accessibilityNotes ?? this.accessibilityNotes,
      contentWarning: contentWarning ?? this.contentWarning,
    );
  }
}

class SearchKeywords {
  final List<String> seoKeywords;
  final List<String> verseSearchKeyword;
  final List<String> categoryTags;
  final List<String> industryTags;
  final bool generatedByAi;
  final bool manuallyEntered;

  SearchKeywords({
    required this.seoKeywords,
    required this.verseSearchKeyword,
    required this.categoryTags,
    required this.industryTags,
    required this.generatedByAi,
    required this.manuallyEntered,
  });

  SearchKeywords copyWith({
    List<String>? seoKeywords,
    List<String>? verseSearchKeyword,
    List<String>? categoryTags,
    List<String>? industryTags,
    bool? generatedByAi,
    bool? manuallyEntered,
  }) {
    return SearchKeywords(
      seoKeywords: seoKeywords ?? this.seoKeywords,
      verseSearchKeyword: verseSearchKeyword ?? this.verseSearchKeyword,
      categoryTags: categoryTags ?? this.categoryTags,
      industryTags: industryTags ?? this.industryTags,
      generatedByAi: generatedByAi ?? this.generatedByAi,
      manuallyEntered: manuallyEntered ?? this.manuallyEntered,
    );
  }
}

class InternalNotes {
  final String notes;
  final String priority;
  final bool reviewRequired;
  final String reviewerNotes;

  InternalNotes({
    required this.notes,
    required this.priority,
    required this.reviewRequired,
    required this.reviewerNotes,
  });

  InternalNotes copyWith({
    String? notes,
    String? priority,
    bool? reviewRequired,
    String? reviewerNotes,
  }) {
    return InternalNotes(
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      reviewRequired: reviewRequired ?? this.reviewRequired,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
    );
  }
}
