import 'package:flutter/material.dart';

class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // Available currencies
  static const Map<String, CurrencyInfo> _currencies = {
    'ZAR': CurrencyInfo(
      code: 'ZAR',
      symbol: 'R',
      name: 'South African Rand',
      flag: '🇿🇦',
      position: CurrencyPosition.before,
    ),
    'USD': CurrencyInfo(
      code: 'USD',
      symbol: '\$',
      name: 'US Dollar',
      flag: '🇺🇸',
      position: CurrencyPosition.before,
    ),
    'EUR': CurrencyInfo(
      code: 'EUR',
      symbol: '€',
      name: 'Euro',
      flag: '🇪🇺',
      position: CurrencyPosition.before,
    ),
    'GBP': CurrencyInfo(
      code: 'GBP',
      symbol: '£',
      name: 'British Pound',
      flag: '🇬🇧',
      position: CurrencyPosition.before,
    ),
    'CAD': CurrencyInfo(
      code: 'CAD',
      symbol: 'C\$',
      name: 'Canadian Dollar',
      flag: '🇨🇦',
      position: CurrencyPosition.before,
    ),
    'AUD': CurrencyInfo(
      code: 'AUD',
      symbol: 'A\$',
      name: 'Australian Dollar',
      flag: '🇦🇺',
      position: CurrencyPosition.before,
    ),
    'JPY': CurrencyInfo(
      code: 'JPY',
      symbol: '¥',
      name: 'Japanese Yen',
      flag: '🇯🇵',
      position: CurrencyPosition.before,
    ),
    'CHF': CurrencyInfo(
      code: 'CHF',
      symbol: 'CHF',
      name: 'Swiss Franc',
      flag: '🇨🇭',
      position: CurrencyPosition.after,
    ),
    'NGN': CurrencyInfo(
      code: 'NGN',
      symbol: '₦',
      name: 'Nigerian Naira',
      flag: '🇳🇬',
      position: CurrencyPosition.before,
    ),
    'KES': CurrencyInfo(
      code: 'KES',
      symbol: 'KSh',
      name: 'Kenyan Shilling',
      flag: '🇰🇪',
      position: CurrencyPosition.before,
    ),
    'GHS': CurrencyInfo(
      code: 'GHS',
      symbol: 'GH₵',
      name: 'Ghanaian Cedi',
      flag: '🇬🇭',
      position: CurrencyPosition.before,
    ),
    'EGP': CurrencyInfo(
      code: 'EGP',
      symbol: 'E£',
      name: 'Egyptian Pound',
      flag: '🇪🇬',
      position: CurrencyPosition.before,
    ),
  };

  String _selectedCurrency = 'ZAR'; // Default to South African Rand

  // Getters
  String get selectedCurrency => _selectedCurrency;
  CurrencyInfo get currentCurrency => _currencies[_selectedCurrency]!;
  Map<String, CurrencyInfo> get allCurrencies => Map.unmodifiable(_currencies);

  // Format currency amount
  String formatAmount(double amount, {bool showCode = false}) {
    final currency = currentCurrency;
    final formattedAmount = _formatNumber(amount);
    
    if (currency.position == CurrencyPosition.before) {
      return showCode 
          ? '$formattedAmount ${currency.symbol} (${currency.code})'
          : '${currency.symbol}$formattedAmount';
    } else {
      return showCode 
          ? '$formattedAmount ${currency.symbol} (${currency.code})'
          : '$formattedAmount ${currency.symbol}';
    }
  }

  // Format large amounts with K, M, B suffixes
  String formatLargeAmount(double amount, {bool showCode = false}) {
    final currency = currentCurrency;
    String formattedAmount;
    
    if (amount >= 1000000000) {
      formattedAmount = '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      formattedAmount = '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      formattedAmount = '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      formattedAmount = _formatNumber(amount);
    }
    
    if (currency.position == CurrencyPosition.before) {
      return showCode 
          ? '$formattedAmount ${currency.symbol} (${currency.code})'
          : '${currency.symbol}$formattedAmount';
    } else {
      return showCode 
          ? '$formattedAmount ${currency.symbol} (${currency.code})'
          : '$formattedAmount ${currency.symbol}';
    }
  }

  // Change currency
  void setCurrency(String currencyCode) {
    if (_currencies.containsKey(currencyCode) && _selectedCurrency != currencyCode) {
      _selectedCurrency = currencyCode;
      notifyListeners();
    }
  }

  // Format number with appropriate decimal places
  String _formatNumber(double amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  // Get currency list for dropdowns
  List<MapEntry<String, CurrencyInfo>> get currencyList {
    return _currencies.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
  }
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String flag;
  final CurrencyPosition position;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
    required this.position,
  });
}

enum CurrencyPosition {
  before,
  after,
}







