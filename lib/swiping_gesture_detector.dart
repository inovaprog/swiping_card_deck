import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class SwipingGestureDetector extends StatefulWidget {
  SwipingGestureDetector({
    Key? key,
    required this.cardDeck,
    required this.onLeftSwipe,
    required this.onRightSwipe,
    required this.onDeckEmpty,
    required this.swipeLeft,
    required this.swipeRight,
    required this.cardWidth,
    this.minimumVelocity = 1000,
    this.rotationFactor = .8 / 3.14,
    required this.swipeThreshold,
  }) : super(key: key);

  final List<Card> cardDeck;
  final Function(Card) onLeftSwipe, onRightSwipe;
  final Function(Size) swipeLeft, swipeRight;
  final Function() onDeckEmpty;
  final double minimumVelocity;
  final double rotationFactor;
  final double swipeThreshold;
  final double cardWidth;

  Alignment dragAlignment = Alignment.center;
  late final Animation<Alignment> animation;
  late final AnimationController controller;
  late final AnimationController swipeController;
  late final Animation<double> swipe;

  @override
  State<StatefulWidget> createState() => _SwipingGestureDetector();
}

class _SwipingGestureDetector extends State<SwipingGestureDetector> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.controller = AnimationController(vsync: this);
    widget.controller.addListener(() {
      setState(() {
        widget.dragAlignment = widget.animation.value;
      });
    });

    widget.swipeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 500)
    );
    widget.swipeController.addListener(() {
      setState(() {
        widget.dragAlignment = Alignment(widget.swipe.value, widget.dragAlignment.y);
      });
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    widget.swipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onPanUpdate: (DragUpdateDetails details) {
        setState(() {
          widget.dragAlignment += Alignment(
            details.delta.dx, 
            details.delta.dy
          );
        });
      },
      onPanEnd: (DragEndDetails details) async {
        double vx = details.velocity.pixelsPerSecond.dx;
        if (vx > widget.minimumVelocity || widget.dragAlignment.x > widget.swipeThreshold) {
          await widget.swipeRight(MediaQuery.of(context).size);
        } else if (vx < -widget.minimumVelocity ||  widget.dragAlignment.x < -widget.swipeThreshold) {
          await widget.swipeLeft(MediaQuery.of(context).size);
        } else {
          animateBackToDeck(details.velocity.pixelsPerSecond, screenSize);
        }
        setState(() {
          widget.dragAlignment = Alignment.center;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: topTwoCards(),
      ),
    );
  }

  List<Widget> topTwoCards() {
    if (widget.cardDeck.isEmpty) {
      return [const SizedBox(height: 0, width: 0,)];
    }
    List<Widget> cardDeck = [];
    for (int i = max(widget.cardDeck.length - 2, 0); i < widget.cardDeck.length; ++i) {
      cardDeck.add(widget.cardDeck[i]);
    }
    Widget topCard = cardDeck.last;
    cardDeck.removeLast();
    cardDeck.add(
      Align(
        alignment: Alignment(getCardXPosition(), 0),
        child: Transform.rotate(
          angle: getCardAngle(),
          child: topCard,
        )
      ),
    );
    return cardDeck;
  }

  double getCardAngle() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.rotationFactor * (widget.dragAlignment.x / screenWidth);
  }

  double getCardXPosition() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.dragAlignment.x / ((screenWidth - widget.cardWidth) / 2);
  }

  void animateBackToDeck(Offset pixelsPerSecond, Size size) async{
    widget.animation = widget.controller.drive(
      AlignmentTween(
        begin: widget.dragAlignment,
        end: Alignment.center,
      ),
    );

    // Calculate the velocity relative to the unit interval, [0,1],
    // used by the animation controller.
    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;
    
    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    await widget.controller.animateWith(simulation);
  }
}