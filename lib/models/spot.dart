class Spot {
  double lat;
  double long;
  double timeLim;
  String zoneType;
  String parkType;
  bool occupied;

  Spot(this.long, this.lat, this.timeLim, this.zoneType, this.parkType,
      this.occupied);
}
