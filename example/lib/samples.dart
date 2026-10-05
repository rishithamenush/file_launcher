import 'package:flutter/material.dart';

class FileSample {
  const FileSample(
    this.name,
    this.label,
    this.category,
    this.detail,
    this.icon, {
    this.mimeType,
  });
  final String name;
  final String label;
  final String category;
  final String detail;
  final IconData icon;
  final String? mimeType;
}

const fileSamples = [
  FileSample(
    'sample.pdf',
    'PDF document',
    'Documents',
    'A small, valid PDF',
    Icons.picture_as_pdf_outlined,
  ),
  FileSample(
    'sample.docx',
    'Word document',
    'Documents',
    'A real DOCX document',
    Icons.description_outlined,
  ),
  FileSample(
    'sample.xlsx',
    'Excel workbook',
    'Documents',
    'A real XLSX workbook',
    Icons.table_chart_outlined,
  ),
  FileSample(
    'sample.mp3',
    'MP3 audio',
    'Audio',
    '3-second soft test tone',
    Icons.music_note_outlined,
  ),
  FileSample(
    'sample.m4a',
    'M4A audio',
    'Audio',
    'AAC in an MPEG-4 container',
    Icons.graphic_eq,
  ),
  FileSample(
    'sample.wav',
    'WAV audio',
    'Audio',
    'Uncompressed PCM audio',
    Icons.multitrack_audio,
  ),
  FileSample(
    'sample.flac',
    'FLAC audio',
    'Audio',
    'Lossless audio sample',
    Icons.album_outlined,
  ),
  FileSample(
    'sample.ogg',
    'Ogg audio',
    'Audio',
    'Vorbis audio sample',
    Icons.audiotrack_outlined,
  ),
  FileSample(
    'sample.opus',
    'Opus audio',
    'Audio',
    'Opus in an Ogg container',
    Icons.headphones_outlined,
  ),
  FileSample(
    'sample.aac',
    'AAC audio',
    'Audio',
    'Raw ADTS audio sample',
    Icons.equalizer,
  ),
  FileSample(
    'sample.mp4',
    'MP4 video',
    'Video',
    'A short H.264 video',
    Icons.play_circle_outline,
  ),
  FileSample(
    'sample.png',
    'PNG image',
    'Images',
    'Lossless image sample',
    Icons.image_outlined,
  ),
  FileSample(
    'sample.jpg',
    'JPEG image',
    'Images',
    'Photo-compatible image format',
    Icons.photo_outlined,
  ),
  FileSample(
    'sample.txt',
    'Plain text',
    'Data',
    'A readable text document',
    Icons.notes,
  ),
  FileSample(
    'sample.csv',
    'CSV table',
    'Data',
    'A tiny table with a header',
    Icons.grid_on_outlined,
  ),
  FileSample(
    'sample.json',
    'JSON data',
    'Data',
    'A valid JSON object',
    Icons.data_object,
  ),
  FileSample(
    'sample.zip',
    'ZIP archive',
    'Other',
    'An archive containing a text file',
    Icons.folder_zip_outlined,
  ),
  FileSample(
    'sample.xyz',
    'Unknown format',
    'Other',
    'Explore the device’s fallback',
    Icons.help_outline,
  ),
  FileSample(
    'no_extension',
    'PDF without extension',
    'Other',
    'Supplies application/pdf on Android',
    Icons.file_present_outlined,
    mimeType: 'application/pdf',
  ),
];
