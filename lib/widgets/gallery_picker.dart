import 'package:flutter/material.dart';
import 'dart:io';

class GalleryPicker extends StatefulWidget {
  final List<File> selectedImages;
  final Function(List<File>) onImagesSelected;
  final int maxImages;
  final bool allowMultiple;
  
  const GalleryPicker({
    super.key,
    required this.selectedImages,
    required this.onImagesSelected,
    this.maxImages = 10,
    this.allowMultiple = true,
  });

  @override
  State<GalleryPicker> createState() => _GalleryPickerState();
}

class _GalleryPickerState extends State<GalleryPicker> {
  List<File> _tempSelectedImages = [];

  @override
  void initState() {
    super.initState();
    _tempSelectedImages = List.from(widget.selectedImages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Select Photos',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_tempSelectedImages.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Done (${_tempSelectedImages.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected images preview
          if (_tempSelectedImages.isNotEmpty) ...[
            Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tempSelectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _tempSelectedImages[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white24),
          ],
          
          // Gallery grid
          Expanded(
            child: FutureBuilder<List<File>>(
              future: _getGalleryImages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading gallery: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                final images = snapshot.data ?? [];
                
                if (images.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No images found in gallery',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final image = images[index];
                    final isSelected = _tempSelectedImages.contains(image);
                    
                    return GestureDetector(
                      onTap: () => _toggleImageSelection(image),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              image,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.blue.withOpacity(0.7),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFromCamera,
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera_alt, color: Colors.black),
      ),
    );
  }

  Future<List<File>> _getGalleryImages() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd use a proper gallery package like:
      // - photo_manager
      // - gallery_saver
      // - or implement custom gallery access
      
      // For now, we'll return an empty list and show a message
      // that prompts the user to use the camera or pick individual images
      return [];
    } catch (e) {
      print('Error getting gallery images: $e');
      return [];
    }
  }

  void _toggleImageSelection(File image) {
    setState(() {
      if (_tempSelectedImages.contains(image)) {
        _tempSelectedImages.remove(image);
      } else {
        if (_tempSelectedImages.length < widget.maxImages) {
          _tempSelectedImages.add(image);
        } else {
          _showMaxImagesReachedDialog();
        }
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _tempSelectedImages.removeAt(index);
    });
  }

  Future<void> _pickFromCamera() async {
    _showErrorDialog('Camera capture is not available in this build.');
  }

  Future<void> _pickFromGallery() async {
    _showErrorDialog('Gallery picker is not available in this build.');
  }

  void _confirmSelection() {
    widget.onImagesSelected(_tempSelectedImages);
    Navigator.of(context).pop();
  }

  void _showMaxImagesReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Images Reached'),
        content: Text('You can only select up to ${widget.maxImages} images.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Alternative implementation using photo_manager package
class AdvancedGalleryPicker extends StatefulWidget {
  final List<File> selectedImages;
  final Function(List<File>) onImagesSelected;
  final int maxImages;
  
  const AdvancedGalleryPicker({
    super.key,
    required this.selectedImages,
    required this.onImagesSelected,
    this.maxImages = 10,
  });

  @override
  State<AdvancedGalleryPicker> createState() => _AdvancedGalleryPickerState();
}

class _AdvancedGalleryPickerState extends State<AdvancedGalleryPicker> {
  List<File> _tempSelectedImages = [];
  List<File> _galleryImages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tempSelectedImages = List.from(widget.selectedImages);
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // This would use photo_manager package to load actual gallery images
      // For now, we'll simulate loading
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulate gallery images
      _galleryImages = [];
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gallery',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_tempSelectedImages.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Done (${_tempSelectedImages.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGalleryImages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_galleryImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No images in gallery',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Use the camera button to take photos',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Selected images preview
        if (_tempSelectedImages.isNotEmpty) ...[
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tempSelectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _tempSelectedImages[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),
        ],
        
        // Gallery grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _galleryImages.length,
            itemBuilder: (context, index) {
              final image = _galleryImages[index];
              final isSelected = _tempSelectedImages.contains(image);
              
              return GestureDetector(
                onTap: () => _toggleImageSelection(image),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.withOpacity(0.7),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _toggleImageSelection(File image) {
    setState(() {
      if (_tempSelectedImages.contains(image)) {
        _tempSelectedImages.remove(image);
      } else {
        if (_tempSelectedImages.length < widget.maxImages) {
          _tempSelectedImages.add(image);
        } else {
          _showMaxImagesReachedDialog();
        }
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _tempSelectedImages.removeAt(index);
    });
  }

  void _confirmSelection() {
    widget.onImagesSelected(_tempSelectedImages);
    Navigator.of(context).pop();
  }

  void _showMaxImagesReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Images Reached'),
        content: Text('You can only select up to ${widget.maxImages} images.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
