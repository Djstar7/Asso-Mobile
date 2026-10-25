import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../core/widgets/app_ui.dart';
import '../controllers/post_controller.dart';

class PostView extends GetView<PostController> {
  const PostView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('post.title'.tr),
        centerTitle: false,
      ),
      body: AppEmptyState(
        icon: Icons.edit_note_rounded,
        title: 'common.coming_soon'.tr,
        message: 'post.working'.tr,
      ),
    );
  }
}
