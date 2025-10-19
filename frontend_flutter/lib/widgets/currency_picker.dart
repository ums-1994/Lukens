import 'package:flutter/material.dart';
import '../services/currency_service.dart';

class CurrencyPicker extends StatelessWidget {
  final String? selectedCurrency;
  final Function(String) onCurrencyChanged;
  final bool showFlag;
  final bool showCode;
  final bool showName;

  const CurrencyPicker({
    super.key,
    this.selectedCurrency,
    required this.onCurrencyChanged,
    this.showFlag = true,
    this.showCode = true,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService();
    final currentCurrency = selectedCurrency ?? currencyService.selectedCurrency;

    return DropdownButtonFormField<String>(
      value: currentCurrency,
      dropdownColor: const Color(0xFF1A1A1B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE9293A)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: currencyService.currencyList.map((entry) {
        final currency = entry.value;
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showFlag) ...[
                Text(
                  currency.flag,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
              ],
              if (showCode) ...[
                Text(
                  currency.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                currency.symbol,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showName) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currency.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onCurrencyChanged(value);
        }
      },
    );
  }
}

class CurrencyDisplay extends StatelessWidget {
  final double amount;
  final bool showCode;
  final bool largeAmount;
  final TextStyle? style;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    this.showCode = false,
    this.largeAmount = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService();
    
    return Text(
      largeAmount 
          ? currencyService.formatLargeAmount(amount, showCode: showCode)
          : currencyService.formatAmount(amount, showCode: showCode),
      style: style ?? const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class CurrencySelector extends StatefulWidget {
  final String? initialCurrency;
  final Function(String)? onChanged;
  final bool showLabel;

  const CurrencySelector({
    super.key,
    this.initialCurrency,
    this.onChanged,
    this.showLabel = true,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency ?? CurrencyService().selectedCurrency;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          const Text(
            'Currency',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        CurrencyPicker(
          selectedCurrency: _selectedCurrency,
          onCurrencyChanged: (currency) {
            setState(() {
              _selectedCurrency = currency;
            });
            CurrencyService().setCurrency(currency);
            widget.onChanged?.call(currency);
          },
          showFlag: true,
          showCode: true,
          showName: true,
        ),
      ],
    );
  }
}







