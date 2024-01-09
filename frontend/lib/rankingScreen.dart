import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  Future<List<BrandInfo>> fetchAndRankBrands() async {
    try {
      final brandResponse =
          await http.get(Uri.parse('http://localhost:3000/brands'));
      final List<dynamic> brandData = json.decode(brandResponse.body);

      final trendResponse =
          await http.get(Uri.parse('http://localhost:3000/trends'));
      final List<dynamic> trendData = json.decode(trendResponse.body);

      Map<String, double> brandOccurrences = {};
      for (int i = 0; i < trendData.length; i++) {
        var trend = trendData[i];
        for (var brand in brandData) {
          if (trend['headline'].contains(brand['brand_name'])) {
            double weight = getWeightForIndex(i);
            brandOccurrences[brand['brand_name']] =
                (brandOccurrences[brand['brand_name']] ?? 0) + weight;
          }
        }
      }

      final rankedBrands = brandOccurrences.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final rankedBrandInfo = rankedBrands.map((entry) {
        final brand = brandData.firstWhere((b) => b['brand_name'] == entry.key);
        return BrandInfo(name: entry.key, imageUrl: brand['image_url']);
      }).toList();

      return rankedBrandInfo;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("PRIMA",
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
              painter: RoundedLinePainter(), size: const Size.fromHeight(3.0)),
        ),
      ),
      body: FutureBuilder<List<BrandInfo>>(
        future: fetchAndRankBrands(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return Container(
              color: Colors.black,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "BRAND RANKINGS",
                    style: TextStyle(
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        BrandInfo brand = snapshot.data![index];
                        Color numberColor;
                        if (index < 10) {
                          numberColor = Colors.green;
                        } else if (index < 25) {
                          numberColor = Colors.orange;
                        } else {
                          numberColor = Colors.red;
                        }
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 24),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                      shape: BoxShape.rectangle,
                                    ),
                                    child: Image.network(
                                      brand.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return buildPlaceholderImage();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    brand.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Vogue',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Column(
                                children: [
                                  Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: numberColor,
                                      fontFamily: 'Vogue',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(child: Text('No brands found'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Icon(Icons.list),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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
