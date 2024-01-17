import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:grocery_app/data/categories.dart';
import 'package:grocery_app/models/grocery_item.dart';
import 'package:grocery_app/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({Key? key}) : super(key: key);

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItems = [];
  List<GroceryItem> _filteredItems = [];
  var _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    final url = Uri.https(
        'grocery-list-df4f4-default-rtdb.firebaseio.com', 'grocery-list.json');

    try {
      final response = await http.get(url);

      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch data. Please try again later.';
        });
      }

      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];
      for (final item in listData.entries) {
        final category = categories.entries
            .firstWhere(
                (catItem) => catItem.value.title == item.value['category'])
            .value;
        loadedItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }
      setState(() {
        _groceryItems = loadedItems;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Something went wrong! Please try again later.';
      });
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => const NewItem(),
      ),
    );

    if (newItem == null) {
      return;
    }

    setState(() {
      _groceryItems.add(newItem);
    });
  }

  void _removeItem(GroceryItem item) async {
    final index = _groceryItems.indexOf(item);
    setState(() {
      _groceryItems.remove(item);
    });

    final url = Uri.https('grocery-list-df4f4-default-rtdb.firebaseio.com',
        'grocery-list/${item.id}.json');

    final response = await http.delete(url);

    if (response.statusCode >= 400) {
      setState(() {
        _groceryItems.insert(index, item);
      });
    }
  }

  void _editItem(GroceryItem item) async {
    final editedItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => NewItem(
          editItem: item,
        ),
      ),
    );

    if (editedItem != null) {
      _removeItem(item);

      setState(() {
        _groceryItems.add(editedItem);
      });

      _updateItemOnServer(editedItem);
    }
  }

  void _updateItemOnServer(GroceryItem editedItem) async {
    final url = Uri.https('grocery-list-df4f4-default-rtdb.firebaseio.com',
        'grocery-list/${editedItem.id}.json');

    try {
      final response = await http.put(
        url,
        body: json.encode({
          'name': editedItem.name,
          'quantity': editedItem.quantity,
          'category': editedItem.category.title,
        }),
      );

      if (response.statusCode >= 400) {
        print('Failed to update item on server.');
      }
    } catch (error) {
      print('Error updating item on server: $error');
    }
  }


  void _filterItems(String query) {
    setState(() {
      _filteredItems = _groceryItems
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groceryItems.isNotEmpty
              ? _filteredItems.isNotEmpty
                  ? _buildGroupedListView(_filteredItems)
                  : _buildGroupedListView(_groceryItems)
              : const Center(child: Text('No items added yet.')),
    );
  }

  Widget _buildGroupedListView(List<GroceryItem> items) {
    Map<String, List<GroceryItem>> groupedItems =
        groupBy(items, (item) => item.category.title);

    return ListView.builder(
      itemCount: groupedItems.length,
      itemBuilder: (ctx, index) {
        String category = groupedItems.keys.elementAt(index);
        List<GroceryItem> categoryItems = groupedItems[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: categoryItems.length,
              itemBuilder: (ctx, i) {
                return Dismissible(
                  onDismissed: (direction) {
                    _removeItem(categoryItems[i]);
                  },
                  key: ValueKey(categoryItems[i].id),
                  child: ListTile(
                    title: Text(categoryItems[i].name),
                    leading: Container(
                      width: 24,
                      height: 24,
                      color: categoryItems[i].category.color,
                    ),
                    trailing: Text(
                      categoryItems[i].quantity.toString(),
                    ),
                    onTap: () {
                      _editItem(categoryItems[i]);
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T) key) {
    Map<String, List<T>> result = {};

    for (T item in items) {
      String category = key(item).toString();
      (result[category] ??= []).add(item);
    }

    return result;
  }
}
