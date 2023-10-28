import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    SafeArea(child: GameWidget(game: SnafuGame())),
  );
}

enum Direction { north, west, east, south }

typedef Coordinate = ({int x, int y});

class SnafuGame extends FlameGame
    with
        TapDetector,
        HorizontalDragDetector,
        VerticalDragDetector,
        TapDetector {
  static const movementTickDuration = 1;
  Board board = Board();
  SnakeComponent get player =>
      board.players.firstWhere((player) => player.isAI == false);

  @override
  Future<void> onLoad() async {
    add(board);
  }

  @override
  void onVerticalDragUpdate(DragUpdateInfo info) {
    if (player.direction == Direction.north ||
        player.direction == Direction.south) {
      return;
    }
    if (info.delta.global.y > 0) {
      player.nextDirection = Direction.south;
    } else {
      player.nextDirection = Direction.north;
    }
  }

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    if (player.direction == Direction.west ||
        player.direction == Direction.east) {
      return;
    }
    if (info.delta.global.x > 0) {
      player.nextDirection = Direction.east;
    } else {
      player.nextDirection = Direction.west;
    }
  }

  @override
  void onTap() {
    player.turbo();
  }
}

class Board extends PositionComponent with HasGameRef<SnafuGame> {
  static const int _numberOfLines = 40;
  static const int _numberOfColumns = 20;
  static const double _padding = 10;
  static final Paint _borderColor = Paint()..color = Colors.orange;
  static final Paint _backgroundColor = Paint()..color = Colors.blueGrey;
  Vector2 get cellSize =>
      Vector2(width / _numberOfColumns, height / _numberOfLines);

  List<SnakeComponent> players = [
    SnakeComponent(Colors.red, (x: 5, y: 10), Direction.south),
    SnakeComponent(Colors.green, (x: 5, y: 30), Direction.north, isAI: true),
    SnakeComponent(Colors.blue, (x: 15, y: 10), Direction.east, isAI: true),
    SnakeComponent(Colors.purple, (x: 15, y: 30), Direction.west, isAI: true),
  ];

  Vector2 positionOfCenterOfCell({required Coordinate index}) {
    return Vector2(
      index.x * cellSize.x + cellSize.x / 2,
      index.y * cellSize.y + cellSize.y / 2,
    );
  }

  bool offBoundsOrOccupied(Coordinate index) {
    if (index.x >= _numberOfColumns ||
        index.y >= _numberOfLines ||
        index.x < 0 ||
        index.y < 0) {
      return true;
    }
    for (final player in players) {
      if (player.trail.contains(index) || player.boardCellIndex == index) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> onLoad() async {
    size =
        Vector2(gameRef.size.x - 2 * _padding, gameRef.size.y - 2 * _padding);
    position = Vector2(_padding, _padding);
    players.forEach(add);
  }

  @override
  void render(Canvas canvas) {
    final background = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(background.inflate(5), _borderColor);
    canvas.drawRect(background, _backgroundColor);

    for (final player in players) {
      for (final coordinate in player.trail) {
        final rect = Rect.fromLTWH(
          coordinate.x * cellSize.x,
          coordinate.y * cellSize.y,
          cellSize.x,
          cellSize.y,
        );
        canvas.drawRect(rect, Paint()..color = player.color);
      }
    }
    super.render(canvas);
  }
}

class SnakeComponent extends PositionComponent with HasGameRef<SnafuGame> {
  Color color;
  Coordinate boardCellIndex;
  Direction direction;
  Direction nextDirection;
  double timeSinceLastMovement = 0;
  bool died = false;
  bool isAI;
  static const _slowSpeed = 2.0;
  static const _fastSpeed = 4.0;
  double _velocity = _slowSpeed;
  Set<Coordinate> trail = <Coordinate>{};

  SnakeComponent(
    this.color,
    this.boardCellIndex,
    this.direction, {
    this.isAI = false,
  }) : nextDirection = direction;

  void updatePosition() {
    position = gameRef.board.positionOfCenterOfCell(index: boardCellIndex);
  }

  void turbo() {
    _velocity = _fastSpeed;
    Timer(
        const Duration(
          seconds: 4,
        ), () {
      _velocity = _slowSpeed;
    });
  }

  Direction leftDirection() {
    switch (direction) {
      case Direction.north:
        return Direction.west;
      case Direction.west:
        return Direction.south;
      case Direction.east:
        return Direction.north;
      case Direction.south:
        return Direction.east;
    }
  }

  Direction rightDirection() {
    switch (direction) {
      case Direction.north:
        return Direction.east;
      case Direction.west:
        return Direction.north;
      case Direction.east:
        return Direction.south;
      case Direction.south:
        return Direction.west;
    }
  }

  void changeCellIfAI() {
    if (!isAI) {
      return;
    }
    final candidateDirections = nextPossibleDirections();
    if (candidateDirections.isEmpty) {
      return;
    }
    if (candidateDirections.contains(direction)) {
      if (Random().nextInt(100) < 90) {
        return;
      }
    }
    if (candidateDirections.length > 1) {
      candidateDirections.remove(direction);
    }
    nextDirection =
        candidateDirections[Random().nextInt(candidateDirections.length)];
  }

  Coordinate deltaCoordinateIn(Direction direction) {
    switch (direction) {
      case Direction.north:
        return (x: 0, y: -1);
      case Direction.west:
        return (x: -1, y: 0);
      case Direction.east:
        return (x: 1, y: 0);
      case Direction.south:
        return (x: 0, y: 1);
    }
  }

  Coordinate deltaNextCoordinate() {
    return deltaCoordinateIn(direction);
  }

  List<Direction> nextPossibleDirections() {
    final answer = <Direction>[];
    final possibleDirections = [
      direction,
      leftDirection(),
      rightDirection(),
    ];
    final currentIndex = boardCellIndex;
    for (final candidateDirection in possibleDirections) {
      final delta = deltaCoordinateIn(candidateDirection);
      final candidateCoordinate =
          (x: currentIndex.x + delta.x, y: currentIndex.y + delta.y);

      if (!gameRef.board.offBoundsOrOccupied(candidateCoordinate)) {
        answer.add(candidateDirection);
      }
    }
    return answer;
  }

  @override
  Future<void> onLoad() async {
    size = gameRef.board.cellSize;
    trail.add(boardCellIndex);
    updatePosition();
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    final cell = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(cell, Paint()..color = Colors.black);
    canvas.drawRect(cell.deflate(1), Paint()..color = color);
    super.render(canvas);
  }

  @override
  void update(double dt) {
    timeSinceLastMovement += dt;
    final timeBetweenCells = SnafuGame.movementTickDuration / _velocity;
    if (timeSinceLastMovement > timeBetweenCells) {
      timeSinceLastMovement -= timeBetweenCells;
      final delta = deltaNextCoordinate();
      boardCellIndex =
          (x: boardCellIndex.x + delta.x, y: boardCellIndex.y + delta.y);
      trail.add(boardCellIndex);
      changeCellIfAI();
      direction = nextDirection;

      final deltaNextCell = deltaNextCoordinate();
      died = gameRef.board.offBoundsOrOccupied(
        (
          x: boardCellIndex.x + deltaNextCell.x,
          y: boardCellIndex.y + deltaNextCell.y,
        ),
      );

      if (died) {
        trail = <Coordinate>{};
        gameRef.board.remove(this);
      }
    }
    final delta = deltaNextCoordinate();
    position.x += _velocity * size.x * delta.x * dt;
    position.y += _velocity * size.y * delta.y * dt;
  }
}
