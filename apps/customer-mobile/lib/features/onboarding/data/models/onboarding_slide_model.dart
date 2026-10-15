import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/onboarding_slide.dart';

const List<OnboardingSlide> onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    title: 'Welcome to SafeShift',
    description: "Moving people's property safely — right from your phone.",
    lottieAsset: 'assets/lottie/9604020.lottie',
    accentColor: AppColors.primary,
  ),
  OnboardingSlide(
    title: 'Book in Seconds',
    description: 'Enter your pickup and destination, choose a vehicle, and get a transparent quote — no haggling.',
    lottieAsset: 'assets/lottie/9604018.lottie',
    accentColor: AppColors.secondary,
  ),
  OnboardingSlide(
    title: 'Track Every Move',
    description: 'Verified drivers, live tracking, digital proof of delivery, and a structured protection model.',
    lottieAsset: 'assets/lottie/9604020.lottie',
    accentColor: AppColors.success,
  ),
];
