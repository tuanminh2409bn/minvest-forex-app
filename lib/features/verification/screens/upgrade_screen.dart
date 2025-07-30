import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/verification/screens/account_verification_screen.dart';
import 'package:minvest_forex_app/features/verification/screens/package_screen.dart';
import 'package:minvest_forex_app/features/verification/models/payment_method.dart';
import 'package:url_launcher/url_launcher.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'UPGRADE ACCOUNT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'COMPARE TIERS',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                _buildTiersTable(),
                const SizedBox(height: 30),
                _buildActionButton(
                  context,
                  text: 'Open exness account!',
                  onPressed: () {
                    _launchURL('https://my.exmarkets.guide/accounts/sign-up/303589?utm_source=partners&ex_ol=1');
                  },
                  isPrimary: false,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  text: 'Account verification with Exness',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AccountVerificationScreen()),
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  text: 'Pay in app to upgrade',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PackageScreen(paymentMethod: PaymentMethod.inAppPurchase)),
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  text: 'Bank transfer to upgrade',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PackageScreen(paymentMethod: PaymentMethod.vnPay)),
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTiersTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.blueGrey.withOpacity(0.3), width: 1),
          verticalInside: BorderSide(color: Colors.blueGrey.withOpacity(0.3), width: 1),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.6),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          _buildTableRow(['Feature', 'Demo', 'Vip', 'Elite'], isHeader: true),
          _buildTableRow(['Balance', '< \$200', '> \$200', '> \$500']),
          _buildTableRow(['Signal time', '8h-17h', '8h-17h', 'fulltime']),
          _buildTableRow(['Signal Qty', '7-8/day', 'full', 'full']),
          _buildTableRow(['Analysis', 'icon:cancel', 'icon:cancel', 'icon:check']),
          _buildTableRow(['Lot/week', '0.05', '0.3', '0.5']),
        ],
      ),
    );
  }

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader ? const BoxDecoration(color: Color(0xFF151a2e)) : null,
      children: cells.map((cell) {
        final isFirstCell = cells.indexOf(cell) == 0;
        Widget cellWidget;

        if (cell.startsWith('icon:')) {
          IconData iconData = cell == 'icon:check' ? Icons.check_circle : Icons.cancel;
          Color iconColor = cell == 'icon:check' ? Colors.greenAccent : Colors.redAccent;
          cellWidget = Icon(iconData, color: iconColor, size: 18);
        } else {
          cellWidget = Text(
            cell,
            textAlign: isFirstCell ? TextAlign.left : TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: isHeader ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          );
        }

        return TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Container(
            decoration: (isHeader && !isFirstCell)
                ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)],
              ),
            )
                : (isHeader && isFirstCell)
                ? const BoxDecoration(
              color: Color(0xFF172AFE),
            )
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: isFirstCell ? 12.0 : 4.0),
              child: cellWidget,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context, {required String text, required VoidCallback onPressed, required bool isPrimary}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
              colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: isPrimary ? null : const Color(0xFF151a2e),
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: Colors.blueAccent),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}