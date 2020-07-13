import 'dart:async';

import 'package:Eliverd/models/models.dart';
import 'package:Eliverd/ui/widgets/stock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Eliverd/bloc/events/storeEvent.dart';
import 'package:Eliverd/bloc/states/storeState.dart';
import 'package:Eliverd/bloc/storeBloc.dart';

import 'package:Eliverd/common/string.dart';
import 'package:Eliverd/common/color.dart';

import 'package:Eliverd/ui/pages/my_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Completer<GoogleMapController> _controller = Completer();
  Future<CameraPosition> _getResponses;
  Set<Marker> _stores;

  List<Stock> _carts = [];

  String _searchKeyword = '';

  bool _isSearching = false;
  bool _isInfoSheetExpandedToMaximum = false;

  static const double minExtent = 0.06;
  static const double maxExtentOnKeyboardVisible = 0.45;
  static const double maxExtent = 0.84;

  double initialExtent = 0.36;
  BuildContext draggableSheetContext;

  @override
  void initState() {
    super.initState();

    _getResponses = _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              bottom: 0,
              top: 0,
              left: 0,
              right: 0,
              child: _buildMap(),
            ),
            Positioned(
              top: 0.0,
              left: 0.0,
              child: Container(
                width: width,
                height: height * 0.24,
                color:
                    _shouldSheetExpanded() ? Colors.white : Colors.transparent,
              ),
            ),
            Positioned(
              top: 80.0,
              left: width * 0.05,
              child: Container(
                width: width * 0.9,
                height: 24.0,
                padding: EdgeInsets.symmetric(
                  vertical: 1.0,
                ),
                child: GridView(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.28,
                  ),
                  children: _buildCategoriesList(),
                ),
              ),
            ),
            Positioned(
              top: 32.0,
              left: width * 0.05,
              child: _buildSearchBox(width),
            ),
            Positioned(
              bottom: 0.0,
              child: Container(
                width: width,
                height: height,
                child: SizedBox.expand(
                  child: NotificationListener<DraggableScrollableNotification>(
                    onNotification: _toggleInfoSheetExtentByListener,
                    child: DraggableScrollableActuator(
                      child: DraggableScrollableSheet(
                        key: Key(initialExtent.toString()),
                        minChildSize: minExtent,
                        maxChildSize: maxExtent,
                        initialChildSize: initialExtent,
                        builder: _draggableScrollableSheetBuilder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _gesterRecognizer = <Factory<OneSequenceGestureRecognizer>>[
    Factory<OneSequenceGestureRecognizer>(
      () => EagerGestureRecognizer(),
    ),
  ].toSet();

  bool _shouldSheetExpanded() => _isSearching || _isInfoSheetExpandedToMaximum;

  Widget _draggableScrollableSheetBuilder(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    draggableSheetContext = context;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(50.0),
          topRight: Radius.circular(50.0),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: height / 80.0),
          Divider(
            indent: 120.0,
            endIndent: 120.0,
            height: 16.0,
            thickness: 4.0,
          ),
          SizedBox(height: height / 80.0),
          Expanded(
            flex: 1,
            child: ListView(
              physics: _isSearching
                  ? NeverScrollableScrollPhysics()
                  : BouncingScrollPhysics(),
              controller: scrollController,
              children: <Widget>[
                _buildHomeSheetByState(width, height),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _toggleInfoSheetExtentByListener(
      DraggableScrollableNotification notification) {
    setState(() {
      if (notification.extent >= maxExtent) {
        _isInfoSheetExpandedToMaximum = true;
      } else {
        _isInfoSheetExpandedToMaximum = false;
      }
    });

    return false;
  }

  void _changeDraggableScrollableSheet(double extent) {
    if (draggableSheetContext != null) {
      setState(() {
        initialExtent = extent;

        if (extent == maxExtent) {
          _isInfoSheetExpandedToMaximum = true;
        } else {
          _isInfoSheetExpandedToMaximum = false;
        }
      });

      DraggableScrollableActuator.reset(draggableSheetContext);
    }
  }

  void _onCartsChanged(List<Stock> carts) {
    setState(() {
      _carts = carts;
    });
  }

  Future<CameraPosition> _getCurrentLocation() async {
    Position position = await Geolocator().getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);

    LatLng latlng = LatLng(position.latitude, position.longitude);

    return CameraPosition(
      target: latlng,
      zoom: 20.0,
    );
  }

  Future<String> _getAddressFromPosition(LatLng position) async {
    List<Placemark> placemarks = await Geolocator().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
      localeIdentifier: 'ko_KR',
    );

    return placemarks
        .map((placemark) =>
            '${placemark.country} ${placemark.administrativeArea} ${placemark.locality} ${placemark.name} ${placemark.postalCode}')
        .join(',');
  }

  Widget _buildCartButton() => ButtonTheme(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minWidth: 0,
        height: 0,
        child: FlatButton(
          padding: EdgeInsets.all(0.0),
          textColor: Colors.black54,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            '􀍩',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 24.0,
            ),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _buildShoppingCartList(context),
            );
          },
        ),
      );

  Widget _buildUserProfileButton() => ButtonTheme(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minWidth: 0,
        height: 0,
        child: FlatButton(
          padding: EdgeInsets.all(0.0),
          textColor: Colors.black54,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            '􀉩',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 24.0,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyPagePage(),
              ),
            );
          },
        ),
      );

  Widget _buildHomeSheetByState(double width, double height) => _isSearching
      ? _buildSearchResult(width, height)
      : _buildInfoSheet(width, height);

  // TO-DO: 상품 검색 BLOC 로직 추가
  Widget _buildSearchResult(double width, double height) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _searchKeyword,
          ),
        ],
      );

  Widget _buildMap() => Container(
        width: double.infinity,
        height: double.infinity,
        child: FutureBuilder<CameraPosition>(
          future: _getResponses,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                final coordinate = Coordinate(
                  lat: snapshot.data.target.latitude,
                  lng: snapshot.data.target.longitude,
                );

                context.bloc<StoreBloc>().add(FetchStore(coordinate));

                return BlocListener<StoreBloc, StoreState>(
                  listener: (context, state) {
                    if (state is StoreFetched) {
                      print(state.stocks);
                      setState(() {
                        final stocks =
                            groupBy(state.stocks, (stock) => stock.store);

                        _stores = stocks.keys.map((store) {
                          final latlng =
                              LatLng(store.location.lat, store.location.lng);

                          return Marker(
                            markerId: MarkerId(store.id.toString()),
                            position: latlng,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => _buildProductList(
                                    context, store, stocks[store]),
                              );
                            },
                          );
                        }).toSet();
                      });
                    }
                  },
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: snapshot.data,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    gestureRecognizers: _gesterRecognizer,
                    markers: _stores ?? Set.of([]),
                  ),
                );
              } else {
                return RefreshIndicator(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ButtonTheme(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minWidth: 0,
                        height: 0,
                        child: FlatButton(
                          padding: EdgeInsets.all(0.0),
                          textColor: Colors.black12,
                          child: Text(
                            '⟳',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 56.0,
                            ),
                          ),
                          onPressed: () {
                            return _getCurrentLocation();
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(25.0)),
                          ),
                        ),
                      ),
                      Text(
                        HomePageStrings.googleMapCannotBeLoaded,
                        style: TextStyle(
                          color: Colors.black26,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  onRefresh: () {
                    return _getCurrentLocation();
                  },
                );
              }
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    HomePageStrings.googleMapLoading,
                    style: TextStyle(
                      color: Colors.black26,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  CupertinoActivityIndicator(),
                ],
              ),
            );
          },
        ),
      );

  List<Widget> _buildCategoriesList() => <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
          ),
          padding: EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                '􀑉 음식',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
          ),
          padding: EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                '􀍣 생활용품',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.purple,
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
          ),
          padding: EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                '􀖆 의류',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
          ),
          padding: EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                '􀑈 음반',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
      ];

  Widget _buildSearchBox(double width) => Container(
        width: width * 0.9,
        height: 40.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildUserProfileButton(),
            Flexible(
              fit: FlexFit.loose,
              child: CupertinoTextField(
                placeholder: HomePageStrings.searchProductHelperText,
                placeholderStyle: TextStyle(
                  color: Colors.black45,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                onTap: () {
                  _changeDraggableScrollableSheet(maxExtentOnKeyboardVisible);

                  setState(() {
                    _isSearching = true;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    _searchKeyword = value;
                    // TO-DO: 상품 검색 BLOC 이벤트 요청하기
                  });
                },
                onSubmitted: (value) {
                  _changeDraggableScrollableSheet(minExtent);

                  // TO-DO: _buildSearchResult 구현 이후 삭제
                  setState(() {
                    _isSearching = false;
                  });
                },
              ),
            ),
            _buildCartButton(),
          ],
        ),
      );

  Widget _buildProductList(
      BuildContext context, Store store, List<Stock> stocks) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final latlng = LatLng(store.location.lat, store.location.lng);

    Future<String> _getAddress = _getAddressFromPosition(latlng);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: width * 0.85,
          height: height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            store.name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 32.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            store.description,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                          FutureBuilder(
                            future: _getAddress,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                if (snapshot.hasData) {
                                  return Text(
                                    snapshot.data,
                                    overflow: TextOverflow.visible,
                                  );
                                } else if (snapshot.hasError) {
                                  return ButtonTheme(
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    minWidth: 0,
                                    height: 0,
                                    child: FlatButton(
                                      padding: EdgeInsets.all(0.0),
                                      textColor: Colors.black,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      child: Text(
                                        '􀅈',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 24.0,
                                        ),
                                      ),
                                      onPressed: () {
                                        _getAddress = _getAddressFromPosition(latlng);
                                      },
                                    ),
                                  );
                                }
                              }

                              return CupertinoActivityIndicator();
                            },
                          ),
                        ],
                      ),
                    ),
                    ButtonTheme(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minWidth: 0,
                      height: 0,
                      child: FlatButton(
                        padding: EdgeInsets.all(0.0),
                        textColor: Colors.black,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Text(
                          '􀆄',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 24.0,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: StockList(
                  stocks: stocks,
                  onCartsChanged: _onCartsChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TO-DO: 상품 주문 BLOC 요청 로직 추가
  Widget _buildShoppingCartList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: width * 0.85,
          height: height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 1,
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    HomePageStrings.cart,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ButtonTheme(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minWidth: 0,
                    height: 0,
                    child: FlatButton(
                      padding: EdgeInsets.all(0.0),
                      textColor: Colors.black,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Text(
                        '􀆄',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 24.0,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              Text(
                _carts.toString(),
              ),
              CupertinoButton(
                child: Text(
                  HomePageStrings.order,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                color: eliverdColor,
                borderRadius: BorderRadius.circular(25.0),
                padding: EdgeInsets.symmetric(vertical: 15.0),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TO-DO: 배포 직전에 서버와 연동하여 수정
  Widget _buildInfoSheet(double width, double height) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: width,
            height: height * 0.25,
            padding: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [eliverdLightColor, eliverdDarkColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.all(Radius.circular(25.0)),
            ),
            child: Text(
              '누가 봐도 오늘의 대표 상품 소개하는 배너',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 28.0,
              ),
            ),
          ),
          SizedBox(height: height / 40.0),
          Text(
            '카테고리 살펴보기',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 28.0,
            ),
          ),
          SizedBox(height: height / 80.0),
          Container(
            width: width,
            height: height * 0.2,
            child: GridView(
              scrollDirection: Axis.horizontal,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 8.0,
              ),
              children: <Widget>[
                Container(
                  width: width,
                  height: height * 0.2,
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                  ),
                  child: Text(
                    '음식',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 24.0,
                    ),
                  ),
                ),
                Container(
                  width: width,
                  height: height * 0.2,
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                  ),
                  child: Text(
                    '생활용품',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 24.0,
                    ),
                  ),
                ),
                Container(
                  width: width,
                  height: height * 0.2,
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                  ),
                  child: Text(
                    '음반',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 24.0,
                    ),
                  ),
                ),
                Container(
                  width: width,
                  height: height * 0.2,
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                  ),
                  child: Text(
                    '의류',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 24.0,
                    ),
                  ),
                ),
                Container(
                  width: width,
                  height: height * 0.2,
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent,
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                  ),
                  child: Text(
                    '식물',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 24.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: height / 40.0),
          Text(
            '내가 가장 많이 살펴본 물건은?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 28.0,
            ),
          ),
          SizedBox(height: height / 80.0),
          Container(
            width: width,
            height: height * 0.25,
            padding: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              borderRadius: BorderRadius.all(Radius.circular(25.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ㅇㅇㅇ 님은...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 26.0,
                  ),
                ),
                Text(
                  'ㅇㅇ을 가장 좋아하시네요!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 22.0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: height / 40.0),
        ],
      );
}
