import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;

  // Currency, Exchange Rate & Grade Rates (Stored in Base Currency: PKR)
  bool _isPKR = true;
  double _usdExchangeRate = 278.50;
  double _rateA = 500.0;
  double _rateB = 300.0;
  double _rateReject = 50.0;

  // Two-Level Filter State
  String _selectedProduce = 'All Items';
  String _selectedGrade = 'All';
  String _unitLabel = 'Crate';

  /// Formats any PKR amount into either whole PKR ("Rs. 500") or decimal USD ("$1.80")
  String _formatMoney(double pkrAmount) {
    if (_isPKR) {
      return 'Rs. ${pkrAmount.toStringAsFixed(0)}';
    } else {
      final double usdAmount = _usdExchangeRate > 0
          ? (pkrAmount / _usdExchangeRate)
          : 0.0;
      return '\$${usdAmount.toStringAsFixed(2)}';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchScanLogs() async {
    final response = await _supabase
        .from('sorting_logs')
        .select()
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Deletes both the database row and the image file from Supabase Storage
  Future<void> _deleteScan(Map<String, dynamic> item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Scan?"),
        content: Text(
          "Remove '${item['produce_name'] ?? 'this item'}' permanently from cloud history?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final int rowId = item['id'];
      final String? photoUrl = item['photo_url'] as String?;

      await _supabase.from('sorting_logs').delete().eq('id', rowId);

      if (photoUrl != null && photoUrl.isNotEmpty) {
        final fileName = Uri.parse(photoUrl).pathSegments.last;
        await _supabase.storage.from('veg_fruit_scans').remove([fileName]);
      }

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Scan deleted from cloud."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Pop-up dialog supporting decimal inputs for PKR rates and USD exchange rate
  /// Pop-up dialog supporting unit selection (Crate/Kg/Ton) and decimal rates
  void _showRateDialog() {
    final controllerA = TextEditingController(text: _rateA.toString());
    final controllerB = TextEditingController(text: _rateB.toString());
    final controllerR = TextEditingController(text: _rateReject.toString());
    final controllerUsd = TextEditingController(
      text: _usdExchangeRate.toStringAsFixed(2),
    );
    String tempUnit = _unitLabel;
    final unitOptions = ['Crate', 'Kg', 'Ton'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Set Rate per $tempUnit ($_selectedProduce)"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select Pricing Unit:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: unitOptions.map((unit) {
                    final isSelected = tempUnit == unit;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        selectedColor: Colors.green,
                        label: Text(
                          "Per $unit",
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onSelected: (_) {
                          setDialogState(() => tempUnit = unit);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controllerA,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Grade A Rate (PKR / $tempUnit)",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controllerB,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Grade B Rate (PKR / $tempUnit)",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controllerR,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Reject Rate (PKR / $tempUnit)",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Divider(height: 24),
                TextField(
                  controller: controllerUsd,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "1 USD = ? PKR (Exchange Rate)",
                    prefixIcon: Icon(Icons.currency_exchange),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _unitLabel = tempUnit;
                  _rateA = double.tryParse(controllerA.text) ?? _rateA;
                  _rateB = double.tryParse(controllerB.text) ?? _rateB;
                  _rateReject =
                      double.tryParse(controllerR.text) ?? _rateReject;
                  final parsedUsd = double.tryParse(controllerUsd.text);
                  if (parsedUsd != null && parsedUsd > 0) {
                    _usdExchangeRate = parsedUsd;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("Update Totals"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeStatCard({
    required String title,
    required int count,
    required double ratePkr,
    required double totalPkr,
    required Color bgColor,
    required Color textColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: _showRateDialog,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$title: $count",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "@ ${_formatMoney(ratePkr)}/ $_unitLabel",
                style: TextStyle(fontSize: 11, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMoney(totalPkr),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBadgeBackground(String grade) {
    if (grade == 'Grade A') return Colors.green.shade100;
    if (grade == 'Grade B') return Colors.orange.shade100;
    return Colors.red.shade100;
  }

  Color _getBadgeText(String grade) {
    if (grade == 'Grade A') return Colors.green.shade900;
    if (grade == 'Grade B') return Colors.orange.shade900;
    return Colors.red.shade900;
  }

  @override
  Widget build(BuildContext context) {
    final gradeOptions = ['All', 'Grade A', 'Grade B', 'Reject'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text(
          "Scan History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ActionChip(
              backgroundColor: Colors.white,
              label: Text(
                _isPKR ? "PKR" : "USD",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => setState(() => _isPKR = !_isPKR),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Set Rates & Exchange",
            onPressed: _showRateDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchScanLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final allLogs = snapshot.data ?? [];
          if (allLogs.isEmpty) {
            return const Center(child: Text("No scans recorded yet."));
          }

          // 1. Dynamically build the Produce Type list from actual database scans
          final Set uniqueProduce = {'All Items'};
          for (final row in allLogs) {
            final name = (row['produce_name'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              uniqueProduce.add(name);
            }
          }
          final produceOptions = uniqueProduce.toList();
          // Reset filter safely if an item was deleted
          if (!produceOptions.contains(_selectedProduce)) {
            _selectedProduce = 'All Items';
          }
          // 2. Filter logs by Selected Produce Type FIRST (so totals match the selected commodity!)
          final produceLogs = _selectedProduce == 'All Items'
              ? allLogs
              : allLogs
                    .where((item) => item['produce_name'] == _selectedProduce)
                    .toList();
          // 3. Calculate Counts & Valuation Totals for the active Produce selection
          final int countA = produceLogs
              .where((item) => item['grade_rating'] == 'Grade A')
              .length;
          final int countB = produceLogs
              .where((item) => item['grade_rating'] == 'Grade B')
              .length;
          final int countReject = produceLogs
              .where(
                (item) =>
                    item['grade_rating'] != 'Grade A' &&
                    item['grade_rating'] != 'Grade B',
              )
              .length;
          final double totalA = countA * _rateA;
          final double totalB = countB * _rateB;
          final double totalReject = countReject * _rateReject;
          final double grandTotal = totalA + totalB + totalReject;
          // 4. Filter the visible list by Selected Quality Grade SECOND
          final visibleLogs = produceLogs.where((item) {
            final grade = item['grade_rating'] ?? 'Reject';
            if (_selectedGrade == 'All') return true;
            if (_selectedGrade == 'Grade A') return grade == 'Grade A';
            if (_selectedGrade == 'Grade B') return grade == 'Grade B';
            return grade != 'Grade A' && grade != 'Grade B';
          }).toList();
          return Column(
            children: [
              // Grand Total Hero Card
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$_selectedProduce: ${produceLogs.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Total: ${_formatMoney(grandTotal)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              // 3-Column Grade Breakdown Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _buildGradeStatCard(
                      title: "Grade A",
                      count: countA,
                      ratePkr: _rateA,
                      totalPkr: totalA,
                      bgColor: Colors.green.shade100,
                      textColor: Colors.green.shade900,
                    ),
                    const SizedBox(width: 8),
                    _buildGradeStatCard(
                      title: "Grade B",
                      count: countB,
                      ratePkr: _rateB,
                      totalPkr: totalB,
                      bgColor: Colors.orange.shade100,
                      textColor: Colors.orange.shade900,
                    ),
                    const SizedBox(width: 8),
                    _buildGradeStatCard(
                      title: "Reject",
                      count: countReject,
                      ratePkr: _rateReject,
                      totalPkr: totalReject,
                      bgColor: Colors.red.shade100,
                      textColor: Colors.red.shade900,
                    ),
                  ],
                ),
              ),
              // Filter Row 1: Dynamic Produce Type Filter (All Items | Garlic | Potato...)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: produceOptions.map((produce) {
                    final isSelected = _selectedProduce == produce;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        selectedColor: Colors.green.shade800,
                        label: Text(
                          produce,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedProduce = produce);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Filter Row 2: Quality Grade Filter (All | Grade A | Grade B | Reject)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: gradeOptions.map((option) {
                    final isSelected = _selectedGrade == option;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        selectedColor: Colors.green,
                        checkmarkColor: Colors.white,
                        label: Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedGrade = option);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Filtered Scan List with Delete Action
              Expanded(
                child: RefreshIndicator(
                  color: Colors.green,
                  onRefresh: () async => setState(() {}),
                  child: visibleLogs.isEmpty
                      ? Center(
                          child: Text(
                            "No $_selectedGrade scans for $_selectedProduce.",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: visibleLogs.length,
                          itemBuilder: (context, index) {
                            final item = visibleLogs[index];
                            final produceName =
                                item['produce_name'] ?? 'Unknown';
                            final grade = item['grade_rating'] ?? 'Reject';
                            final score = item['texture_score'] ?? 0;
                            final photoUrl = item['photo_url'] as String?;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: photoUrl != null && photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          width: 55,
                                          height: 55,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image),
                                        )
                                      : const Icon(Icons.image),
                                ),
                                title: Text(
                                  produceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text("Texture Score: $score%"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getBadgeBackground(grade),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        grade,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getBadgeText(grade),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      tooltip: "Delete Scan",
                                      onPressed: () => _deleteScan(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
