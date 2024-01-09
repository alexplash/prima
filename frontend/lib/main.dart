import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'rankingScreen.dart';

class BrandInfo {
  final String name;
  final String imageUrl;

  BrandInfo({required this.name, required this.imageUrl});
}

void main() {
  runApp(MainApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  List<BrandInfo> topBrands = [];
  String? selectedCategory;

  Future<List<String>> fetchCategories() async {
    final response =
        await http.get(Uri.parse('http://localhost:3000/categories'));

    if (response.statusCode == 200) {
      List<dynamic> categoriesJson = json.decode(response.body);
      return categoriesJson
          .map((category) => category['category_name'].toString())
          .toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<List<BrandInfo>> fetchTopBrandsForCategory(String category) async {
    try {
      final brandResponse =
          await http.get(Uri.parse('http://localhost:3000/brands'));
      final List<dynamic> brandData = json.decode(brandResponse.body);

      final trendResponse =
          await http.get(Uri.parse('http://localhost:3000/trends'));
      final List<dynamic> trendData = json.decode(trendResponse.body);

      final filteredBrands = brandData
          .where((brand) => (brand['category'] as List).contains(category))
          .toList();

      Map<String, double> brandOccurrences = {};
      for (int i = 0; i < trendData.length; i++) {
        var trend = trendData[i];
        for (var brand in filteredBrands) {
          if (trend['headline'].contains(brand['brand_name'])) {
            double weight = getWeightForIndex(i);
            brandOccurrences[brand['brand_name']] =
                (brandOccurrences[brand['brand_name']] ?? 0) + weight;
          }
        }
      }

      final topBrands = brandOccurrences.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5Brands = topBrands.take(5).map((e) => e.key).toList();

      final topBrandsInfo = top5Brands.map((brandName) {
        final brand = brandData.firstWhere((b) => b['brand_name'] == brandName);
        return BrandInfo(name: brandName, imageUrl: brand['image_url']);
      }).toList();

      return topBrandsInfo;
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  double getWeightForIndex(int index) {
    if (index < 500) return 1.0;
    if (index < 1000) return 0.9;
    if (index < 1500) return 0.8;
    if (index < 2000) return 0.7;
    if (index < 2500) return 0.6;
    return 0.5;
  }

  Widget buildPlaceholderImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.diamond, color: Colors.white, size: 50),
    );
  }

  Widget buildTopBrandsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: topBrands
            .map((brandInfo) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.rectangle,
                        ),
                        child: Image.network(
                          brandInfo.imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return buildPlaceholderImage();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        brandInfo.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Vogue',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget buildCategoryHeader() {
    if (selectedCategory == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          'TRENDING ' + selectedCategory!,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Vogue',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          height: 2.0,
          color: Colors.white,
          width: 100.0,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        canvasColor: Colors.black
      ),
      home: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.list, color: Colors.white),
              onPressed: () {
                navigatorKey.currentState?.push(PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RankingScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, -1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: Container(
                        color: Colors.black,
                        child: child,
                      ),
                    );
                  },
                ));
              },
            ),
            title: const Text('PRIMA',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Vogue',
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 50)),
            backgroundColor: Colors.black,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3.0),
              child: CustomPaint(
                  painter: RoundedLinePainter(),
                  size: const Size.fromHeight(3.0)),
            ),
          ),
          body: Column(children: [
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: fetchCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.hasData) {
                  return Center(
                      child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: snapshot.data!
                          .map((category) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton(
                                  onPressed: () async {
                                    List<BrandInfo> fetchedBrands =
                                        await fetchTopBrandsForCategory(
                                            category);
                                    setState(() {
                                      topBrands = fetchedBrands;
                                      selectedCategory = category;
                                    });
                                  },
                                  child: Text(category,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Vogue',
                                        fontWeight: FontWeight.w300,
                                      )),
                                  style: TextButton.styleFrom(
                                    primary: Colors.white,
                                    backgroundColor: Colors.black,
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 3.0,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ));
                } else {
                  return const Center(child: Text('No categories found'));
                }
              },
            ),
            const SizedBox(height: 20),
            buildCategoryHeader(),
            const SizedBox(height: 20),
            buildTopBrandsRow(),
          ])),
    );
  }
}

class RoundedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
