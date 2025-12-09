import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Displays the local ACS video preview rendered by the platform layer.
class AcsLocalVideoView extends StatelessWidget {
  const AcsLocalVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    return _AcsPlatformVideoView(viewKey: 'localVideoView');
  }
}

/// Displays the remote participant video feed rendered by the platform layer.
class AcsRemoteVideoView extends StatelessWidget {
  const AcsRemoteVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    return _AcsPlatformVideoView(viewKey: 'remoteVideoView');
  }
}

class _AcsPlatformVideoView extends StatelessWidget {
  const _AcsPlatformVideoView({required this.viewKey});

  final String viewKey;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: _viewType,
        creationParams: <String, dynamic>{'viewKey': viewKey},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{'viewKey': viewKey},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  static const String _viewType = 'acs_video_view';
}
