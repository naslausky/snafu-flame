import 'dart:math';

import 'package:flame/components.dart';
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
    with TapDetector, HorizontalDragDetector, VerticalDragDetector {
  static const movementTickDuration = 1;
  late Vector2 screenSize;
  Board board = Board();
  SnakeComponent get player =>
      board.players.firstWhere((player) => player.isAI == false);

  @override
  Future<void> onLoad() async {
    add(board);
  }

  @override
  void onTap() {
    super.onTap();
  }

  @override
  void onVerticalDragUpdate(DragUpdateInfo info) {
    if (player.direction == Direction.north ||
        player.direction == Direction.south) return;
    if (info.delta.global.y > 0) {
      player.nextDirection = Direction.south;
    } else {
      player.nextDirection = Direction.north;
    }
  }

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    if (player.direction == Direction.west ||
        player.direction == Direction.east) return;
    if (info.delta.global.x > 0) {
      player.nextDirection = Direction.east;
    } else {
      player.nextDirection = Direction.west;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    screenSize = size;
    super.onGameResize(size);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }
}

class Board extends PositionComponent with HasGameRef<SnafuGame> {
  static const int _numberOfLines = 40;
  static const int _numberOfColumns = 20;
  static final Paint _backgroundColor = Paint()..color = Colors.yellow;
  static final Paint _gridColor = Paint()..color = Colors.black;
  Vector2 get cellSize =>
      Vector2(width / _numberOfColumns, height / _numberOfLines);
  Map<Coordinate, Color> paintedCells = {};

  List<SnakeComponent> players = [
    SnakeComponent(Colors.red, (x: 5, y: 10), Direction.south),
    SnakeComponent(Colors.green, (x: 5, y: 30), Direction.north, isAI: true),
    SnakeComponent(Colors.blue, (x: 15, y: 10), Direction.east, isAI: true),
    SnakeComponent(Colors.purple, (x: 15, y: 30), Direction.west, isAI: true),
  ];

  Vector2 positionOfCell({required Coordinate index}) {
    return Vector2(index.x * cellSize.x, index.y * cellSize.y);
  }

  bool offBoundsOrOccupied(Coordinate index) {
    if (index.x > _numberOfColumns ||
        index.y > _numberOfLines ||
        index.x < -1 ||
        index.y < -1) return true;
    if (paintedCells.containsKey(index)) return true;
    for (SnakeComponent player in players) {
      if (player.boardCellIndex == index) return true;
    }
    return false;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
  }

  @override
  onLoad() {
    size = Vector2(gameRef.screenSize.x, gameRef.screenSize.y);
    position = Vector2(0, 0);
    players.forEach(add);
  }

  @override
  void render(Canvas canvas) {
    final Rect background = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(background, _backgroundColor);
    for (int lineIndex = 0; lineIndex <= _numberOfLines; lineIndex++) {
      double lineY = (lineIndex / _numberOfLines) * height;
      canvas.drawLine(Offset(0, lineY), Offset(width, lineY), _gridColor);
    }
    for (int columnIndex = 0; columnIndex <= _numberOfColumns; columnIndex++) {
      double lineX = (columnIndex / _numberOfColumns) * width;
      canvas.drawLine(Offset(lineX, 0), Offset(lineX, height), _gridColor);
    }

    for (SnakeComponent snake in players) {
      if (!snake.died) {
        final coordinate = snake.boardCellIndex;
        final rect = Rect.fromLTWH(coordinate.x * cellSize.x,
            coordinate.y * cellSize.y, cellSize.x, cellSize.y);
        canvas.drawRect(rect, Paint()..color = snake.color);
      }
    }

    paintedCells.forEach((Coordinate coordinate, Color color) {
      final rect = Rect.fromLTWH(coordinate.x * cellSize.x,
          coordinate.y * cellSize.y, cellSize.x, cellSize.y);
      canvas.drawRect(rect, Paint()..color = color);
    });

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
  double _velocity = 2;

  SnakeComponent(this.color, this.boardCellIndex, this.direction,
      {this.isAI = false})
      : nextDirection = direction;

  void updatePosition() {
    position = gameRef.board.positionOfCell(index: boardCellIndex);
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

  void turnLeft() {
    nextDirection = leftDirection();
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

  void turnRight() {
    nextDirection = rightDirection();
  }

  void changeCellIfAI() {
    if (!isAI) return;
    final candidateDirections = nextPossibleDirections();
    if (candidateDirections.isEmpty) return;
    if (candidateDirections.contains(direction)) {
      if (Random().nextInt(100) < 50) {
        return;
      }
    }
    candidateDirections.remove(direction);
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
    List<Direction> answer = [];
    List<Direction> possibleDirections = [
      direction,
      leftDirection(),
      rightDirection()
    ];
    final currentDirectionDelta = deltaNextCoordinate();
    final Coordinate currentIndex = (
      x: boardCellIndex.x + currentDirectionDelta.x,
      y: boardCellIndex.y + currentDirectionDelta.y
    );
    for (Direction candidateDirection in possibleDirections) {
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
  onLoad() {
    size = gameRef.board.cellSize;
    gameRef.board.paintedCells[boardCellIndex] = color;
    updatePosition();
    anchor = Anchor.topLeft;
  }

  @override
  void render(Canvas canvas) {
    if (!died) {
      final cell = Rect.fromLTWH(0, 0, width, height);
      canvas.drawRect(cell, Paint()..color = color);
    }
    super.render(canvas);
  }

  @override
  void update(double dt) {
    if (died) return;
    timeSinceLastMovement += dt;
    final timeBetweenCells = SnafuGame.movementTickDuration / _velocity;
    if (timeSinceLastMovement > timeBetweenCells) {
      timeSinceLastMovement -= timeBetweenCells;
      gameRef.board.paintedCells[boardCellIndex] = color;
      changeCellIfAI();
      final delta = deltaNextCoordinate();
      boardCellIndex =
          (x: boardCellIndex.x + delta.x, y: boardCellIndex.y + delta.y);
      direction = nextDirection;
      died = gameRef.board.offBoundsOrOccupied(
          (x: boardCellIndex.x + delta.x, y: boardCellIndex.y + delta.y));
      if (died) {
        gameRef.board.paintedCells.removeWhere((key, value) => value == color);
      }
    }
    final delta = deltaNextCoordinate();
    position.x += _velocity * size.x * delta.x * dt;
    position.y += _velocity * size.y * delta.y * dt;
  }
}
