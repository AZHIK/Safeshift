import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';

class RatingDialog extends StatelessWidget {
  const RatingDialog({
    super.key,
    required this.driverName,
    required this.onRatingSubmitted,
  });
  final String driverName;
  final ValueChanged<int> onRatingSubmitted;

  @override
  Widget build(BuildContext context) {
    var rating = 5;
    return AlertDialog(
      title: const Text('Rate your driver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'How was your experience with $driverName?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.md),
          StatefulBuilder(
            builder: (context, setStars) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                5,
                (index) => IconButton(
                  onPressed: () {
                    rating = index + 1;
                    setStars(() {});
                  },
                  color: rating > index
                      ? const Color(0xFFFFB300)
                      : AppColors.divider,
                  icon: const Icon(Icons.star_rounded),
                  iconSize: 36,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onRatingSubmitted(rating);
          },
          child: Text(
            'Submit',
            style: TextStyles.button.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
