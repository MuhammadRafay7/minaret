import 'package:flutter/material.dart';
// The package exports a `State` model that collides with Flutter's `State`,
// so it is imported with a prefix.
import 'package:country_state_city/country_state_city.dart' as csc;

/// The standardized location a user selected, with both display names and the
/// ISO codes used for reliable filtering/matching.
class LocationValue {
  final String? countryName;
  final String? countryCode; // ISO2, e.g. "PK"
  final String? stateName;
  final String? stateCode; // ISO state code, e.g. "PB"
  final String? cityName;

  const LocationValue({
    this.countryName,
    this.countryCode,
    this.stateName,
    this.stateCode,
    this.cityName,
  });

  /// All three levels chosen.
  bool get isComplete =>
      (countryCode?.isNotEmpty ?? false) &&
      (stateCode?.isNotEmpty ?? false) &&
      (cityName?.isNotEmpty ?? false);

  LocationValue copyWith({
    String? countryName,
    String? countryCode,
    String? stateName,
    String? stateCode,
    String? cityName,
    bool clearState = false,
    bool clearCity = false,
  }) {
    return LocationValue(
      countryName: countryName ?? this.countryName,
      countryCode: countryCode ?? this.countryCode,
      stateName: clearState ? null : (stateName ?? this.stateName),
      stateCode: clearState ? null : (stateCode ?? this.stateCode),
      cityName: clearCity ? null : (cityName ?? this.cityName),
    );
  }
}

/// A cascading Country → State → City picker backed by the offline
/// `country_state_city` dataset. Emits canonical names + ISO codes via
/// [onChanged]. Reusable across registration, profile edit and imam setup.
class LocationPicker extends StatefulWidget {
  final String? initialCountryCode;
  final String? initialStateCode;
  final String? initialCityName;
  final ValueChanged<LocationValue> onChanged;

  /// Optional labels (lets each screen pass localized strings).
  final String countryLabel;
  final String stateLabel;
  final String cityLabel;

  const LocationPicker({
    super.key,
    this.initialCountryCode,
    this.initialStateCode,
    this.initialCityName,
    required this.onChanged,
    this.countryLabel = 'Country',
    this.stateLabel = 'State / Province',
    this.cityLabel = 'City',
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  csc.Country? _country;
  csc.State? _state;
  String? _city;

  List<csc.State> _states = [];
  List<csc.City> _cities = [];

  bool _loadingStates = false;
  bool _loadingCities = false;

  @override
  void initState() {
    super.initState();
    _restoreInitial();
  }

  Future<void> _restoreInitial() async {
    if (widget.initialCountryCode == null) return;
    final country = await csc.getCountryFromCode(widget.initialCountryCode!);
    if (country == null || !mounted) return;
    setState(() => _country = country);
    await _loadStates(country.isoCode);

    if (widget.initialStateCode != null) {
      csc.State? match;
      for (final s in _states) {
        if (s.isoCode == widget.initialStateCode) {
          match = s;
          break;
        }
      }
      if (match != null && mounted) {
        setState(() => _state = match);
        await _loadCities(country.isoCode, match.isoCode);
        if (widget.initialCityName != null && mounted) {
          setState(() => _city = widget.initialCityName);
        }
      }
    }
  }

  Future<void> _loadStates(String countryCode) async {
    setState(() => _loadingStates = true);
    final states = await csc.getStatesOfCountry(countryCode);
    if (!mounted) return;
    states.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _states = states;
      _loadingStates = false;
    });
  }

  Future<void> _loadCities(String countryCode, String stateCode) async {
    setState(() => _loadingCities = true);
    final cities = await csc.getStateCities(countryCode, stateCode);
    if (!mounted) return;
    cities.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _cities = cities;
      _loadingCities = false;
    });
  }

  void _emit() {
    widget.onChanged(LocationValue(
      countryName: _country?.name,
      countryCode: _country?.isoCode,
      stateName: _state?.name,
      stateCode: _state?.isoCode,
      cityName: _city,
    ));
  }

  Future<void> _pickCountry() async {
    final countries = await csc.getAllCountries();
    countries.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    final selected = await _showSearchSheet<csc.Country>(
      title: widget.countryLabel,
      items: countries,
      labelOf: (c) => '${c.flag}  ${c.name}',
      searchOf: (c) => c.name,
    );
    if (selected == null) return;
    setState(() {
      _country = selected;
      _state = null;
      _city = null;
      _states = [];
      _cities = [];
    });
    _emit();
    await _loadStates(selected.isoCode);
  }

  Future<void> _pickState() async {
    if (_country == null) return;
    final selected = await _showSearchSheet<csc.State>(
      title: widget.stateLabel,
      items: _states,
      labelOf: (s) => s.name,
      searchOf: (s) => s.name,
    );
    if (selected == null) return;
    setState(() {
      _state = selected;
      _city = null;
      _cities = [];
    });
    _emit();
    await _loadCities(_country!.isoCode, selected.isoCode);
  }

  Future<void> _pickCity() async {
    if (_state == null) return;
    final selected = await _showSearchSheet<csc.City>(
      title: widget.cityLabel,
      items: _cities,
      labelOf: (c) => c.name,
      searchOf: (c) => c.name,
    );
    if (selected == null) return;
    setState(() => _city = selected.name);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorField(
          label: widget.countryLabel,
          value: _country?.name,
          icon: Icons.public,
          onTap: _pickCountry,
        ),
        const SizedBox(height: 12),
        _SelectorField(
          label: widget.stateLabel,
          value: _state?.name,
          icon: Icons.map_outlined,
          loading: _loadingStates,
          enabled: _country != null,
          onTap: _pickState,
        ),
        const SizedBox(height: 12),
        _SelectorField(
          label: widget.cityLabel,
          value: _city,
          icon: Icons.location_city,
          loading: _loadingCities,
          enabled: _state != null,
          onTap: _pickCity,
        ),
      ],
    );
  }

  /// Generic searchable bottom-sheet selector.
  Future<T?> _showSearchSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    required String Function(T) searchOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = query.isEmpty
                ? items
                : items
                    .where((i) =>
                        searchOf(i).toLowerCase().contains(query.toLowerCase()))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(title,
                          style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matches'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                return ListTile(
                                  title: Text(labelOf(item)),
                                  onTap: () => Navigator.of(ctx).pop(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabled: enabled,
        ),
        child: Text(
          hasValue ? value! : 'Select',
          style: TextStyle(
            color: hasValue
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
