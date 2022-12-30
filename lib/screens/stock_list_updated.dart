import 'package:flutter/material.dart';
// import 'package:stock_watchlist/screens/add_stock.dart';
import 'package:stock_watchlist/screens/web_view.dart';
import 'package:stock_watchlist/classes/stock_class.dart';
import 'package:stock_watchlist/models/db_helper.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

List<Stock> favs = [];
final db = StockDataBase();

void addStockToDb(Stock stock) async {
  await db.addStock(stock);
  //setupList();
}

Future<String> loadStockAsset() async {
  return await rootBundle.loadString('assets/stocks.json');
}

Future<List<Stock>> loadStocks() async {
  String jsonString = await loadStockAsset();
  final jsonResponse = json.decode(jsonString);
  StockBundle s = StockBundle.fromJson(jsonResponse);
  return s.stocks;
}

Future<String> fetchStock(String symbol) async {
  final response = await http.get(Uri.parse(
      'https://query1.finance.yahoo.com/v11/finance/quoteSummary/$symbol.ns?modules=financialData'));
  if (response.statusCode == 200) {
    return '\u{20B9} ${jsonDecode(response.body)['quoteSummary']['result'][0]['financialData']['currentPrice']['raw'].toString()}';
  } else {
    print(response.body);
    throw Exception('Failed to load album');
  }
}

class StockList extends StatefulWidget {
  @override
  _StockListState createState() => _StockListState();
}

class _StockListState extends State<StockList> {
  Future setupList() async {
    var stocks = await db.fetchAll();
    setState(() {
      favs = stocks;
    });
  }

  @override
  void initState() {
    super.initState();
    setupList();
  }

  List<Widget> StackElements(BuildContext context) {
    return <Widget>[
      AppBar(
        backgroundColor: Colors.black,
      ),
      Container(
        height: 200,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50)),
            color: Colors.black),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              child: Text("Stocks",
                  style: new TextStyle(
                      fontFamily: 'Avenir',
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 50)),
            ),
          ],
        ),
      ),
      Container(
        height: 60,
        width: 60,
        margin: EdgeInsets.only(
            top: 170, left: MediaQuery.of(context).size.width * 0.5 - 30),
        child: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            showSearch(context: context, delegate: DataSearch());
          },
          backgroundColor: Colors.red,
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Stack(
            children: StackElements(context),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: setupList,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: favs.length,
                itemBuilder: (context, index) {
                  return OutlinedButton(
                    child: ListTile(
                      title: Center(
                        child: FutureBuilder(
                          future: fetchStock(favs[index].symbol),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                favs[index].nameOfCompany.length > 20
                                    ? favs[index].symbol + " ${snapshot.data}"
                                    : favs[index].nameOfCompany +
                                        " ${snapshot.data}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 20),
                              );
                            }

                            return Text(
                              favs[index].nameOfCompany.length > 20
                                  ? favs[index].symbol
                                  : favs[index].nameOfCompany,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 20),
                            );
                          },
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        new MaterialPageRoute(
                          builder: (BuildContext context) =>
                              new WebPageView(stockName: favs[index].symbol),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

class DataSearch extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = "";
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return null;
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return new FutureBuilder<List<Stock>>(
      future: loadStocks(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return new ListView.builder(
            itemCount: snapshot.data.length,
            itemBuilder: (context, index) {
              final stockName = snapshot.data[index].nameOfCompany.toLowerCase();
              final stockSymbol = snapshot.data[index].symbol.toLowerCase();
              final foundFlag = stockName.startsWith(query.toLowerCase()) || stockSymbol.startsWith(query.toLowerCase());
              if (query.length > 3 && foundFlag) {
                return OutlinedButton(
                  child: new ListTile(
                    title: Text(snapshot.data[index].nameOfCompany),
                    leading: Icon(Icons.ssid_chart),
                    trailing: Text(snapshot.data[index].symbol.toString()),
                  ),
                  onPressed: () {
                    favs.add(snapshot.data[index]);
                    addStockToDb(snapshot.data[index]);
                    close(context, null);
                  },
                );
              } else {
                if (query.length < 3) {
                  return Column();
                } else if (index == 1) {
                  return Center(child: Text("Stock not found"));
                } else {
                  return Center();
                }
              }
            },
          );
        } else if (snapshot.hasError) {
          return new Text("Snapshot Error");
        } else {
          return Center(child: Text("Loading"));
        }
      },
    );
  }
}
