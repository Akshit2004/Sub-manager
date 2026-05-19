import 'package:flutter/material.dart';

class FamilyPageIndicator extends StatelessWidget {
  final int groupsLength;
  final int currentPage;

  const FamilyPageIndicator({
    super.key,
    required this.groupsLength,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(groupsLength + 1, (index) {
            final isActive = currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              height: 6,
              width: isActive ? 18 : 6,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFD4593A) : const Color(0xFFE8E4DE),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        Text(
          currentPage == groupsLength
              ? 'Swipe to View • Create New Group'
              : 'Family ${currentPage + 1} of $groupsLength (Swipe ↔)',
          style: const TextStyle(
            color: Color(0xFFD4593A),
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
