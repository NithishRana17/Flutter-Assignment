import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/models/logbook_entry.dart';
import '../../../providers/providers.dart';

class AddFlightScreen extends ConsumerStatefulWidget {
  final String? editEntryId;
  
  const AddFlightScreen({super.key, this.editEntryId});

  @override
  ConsumerState<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends ConsumerState<AddFlightScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isEditMode = false;
  LogbookEntry? _originalEntry;

  // Step 1: Basic Info
  final _step1FormKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  final _depIcaoController = TextEditingController();
  final _arrIcaoController = TextEditingController();
  final _aircraftRegController = TextEditingController();

  // Step 2: Flight Type & Hours
  final _step2FormKey = GlobalKey<FormState>();
  final List<String> _selectedFlightTypes = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  // Step 3: Hours Breakdown & Remarks
  final _step3FormKey = GlobalKey<FormState>();
  final _picHoursController = TextEditingController(text: '0:00');
  final _sicHoursController = TextEditingController(text: '0:00');       // SIC (Second in Command)
  final _dualHoursController = TextEditingController(text: '0:00');      // Dual Received
  final _dualGivenHoursController = TextEditingController(text: '0:00'); // Dual Given
  final _soloHoursController = TextEditingController(text: '0:00');      // Solo
  final _nightHoursController = TextEditingController(text: '0:00');
  final _xcHoursController = TextEditingController(text: '0:00');
  final _instrumentHoursController = TextEditingController(text: '0:00'); // IMC or Simulated
  final _remarksController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.editEntryId != null) {
      _isEditMode = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEntryForEdit());
    }
  }
  
  void _loadEntryForEdit() {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id ?? '';
    final localStorage = ref.read(localStorageServiceProvider);
    final entry = localStorage.getEntry(widget.editEntryId!);
    
    if (entry != null && entry.userId == userId) {
      _originalEntry = entry;
      setState(() {
        _selectedDate = entry.date;
        _depIcaoController.text = entry.depIcao;
        _arrIcaoController.text = entry.arrIcao;
        _aircraftRegController.text = entry.aircraftReg;
        _selectedFlightTypes.addAll(entry.flightType);
        _startTime = TimeOfDay(hour: entry.startTime.hour, minute: entry.startTime.minute);
        _endTime = TimeOfDay(hour: entry.endTime.hour, minute: entry.endTime.minute);
        // Convert stored decimal hours to H:MM for editing
        _picHoursController.text = TimeUtils.decimalToInput(entry.picHours);
        _sicHoursController.text = TimeUtils.decimalToInput(entry.sicHours);
        _dualHoursController.text = TimeUtils.decimalToInput(entry.dualHours);
        _dualGivenHoursController.text = TimeUtils.decimalToInput(entry.dualGivenHours);
        _soloHoursController.text = TimeUtils.decimalToInput(entry.soloHours);
        _nightHoursController.text = TimeUtils.decimalToInput(entry.nightHours);
        _xcHoursController.text = TimeUtils.decimalToInput(entry.xcHours);
        _instrumentHoursController.text = TimeUtils.decimalToInput(entry.instrumentHours);
        _remarksController.text = entry.remarks ?? '';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _depIcaoController.dispose();
    _arrIcaoController.dispose();
    _aircraftRegController.dispose();
    _picHoursController.dispose();
    _sicHoursController.dispose();
    _dualHoursController.dispose();
    _dualGivenHoursController.dispose();
    _soloHoursController.dispose();
    _nightHoursController.dispose();
    _xcHoursController.dispose();
    _instrumentHoursController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _totalHours {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    var diff = endMinutes - startMinutes;
    if (diff < 0) diff += 24 * 60; // Handle overnight flights
    return diff / 60.0;
  }

  void _goToStep(int step) {
    if (step < 0 || step > 2) return;

    // Validate current step before proceeding
    if (step > _currentStep) {
      if (!_validateCurrentStep()) return;
    }

    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1FormKey.currentState?.validate() ?? false;
      case 1:
        if (_selectedFlightTypes.isEmpty) {
          _showError('Please select at least one flight type');
          return false;
        }
        if (_endTime.hour < _startTime.hour ||
            (_endTime.hour == _startTime.hour &&
                _endTime.minute <= _startTime.minute)) {
          // Allow overnight flights, so this is just a warning
        }
        return _step2FormKey.currentState?.validate() ?? false;
      case 2:
        if (!(_step3FormKey.currentState?.validate() ?? false)) {
          return false;
        }
        // Validate each hour doesn't exceed total
        final pic = TimeUtils.durationToDecimal(_picHoursController.text) ?? 0;
        final dual = TimeUtils.durationToDecimal(_dualHoursController.text) ?? 0;
        final night = TimeUtils.durationToDecimal(_nightHoursController.text) ?? 0;
        final xc = TimeUtils.durationToDecimal(_xcHoursController.text) ?? 0;
        
        final totalStr = TimeUtils.decimalToDuration(_totalHours);
        
        // Use a small epsilon for float comparison errors
        if (pic > _totalHours + 0.01 || dual > _totalHours + 0.01 || 
            night > _totalHours + 0.01 || xc > _totalHours + 0.01) {
          _showError('Individual hours cannot exceed total hours ($totalStr)');
          return false;
        }
        // Note: PIC and Dual CAN overlap (PIC can be logged during dual instruction)
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _saveFlight() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);

    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id ?? '';

    // Create DateTime objects for start and end times
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    var endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // Handle overnight flights
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    bool success;
    
    if (_isEditMode && _originalEntry != null) {
      // Update existing entry
      final entry = _originalEntry!.copyWith(
        date: _selectedDate,
        depIcao: _depIcaoController.text.toUpperCase(),
        arrIcao: _arrIcaoController.text.toUpperCase(),
        aircraftReg: _aircraftRegController.text.toUpperCase(),
        flightType: _selectedFlightTypes,
        startTime: startDateTime,
        endTime: endDateTime,
        totalHours: _totalHours,
        picHours: TimeUtils.durationToDecimal(_picHoursController.text) ?? 0,
        sicHours: TimeUtils.durationToDecimal(_sicHoursController.text) ?? 0,
        dualHours: TimeUtils.durationToDecimal(_dualHoursController.text) ?? 0,
        dualGivenHours: TimeUtils.durationToDecimal(_dualGivenHoursController.text) ?? 0,
        soloHours: TimeUtils.durationToDecimal(_soloHoursController.text) ?? 0,
        nightHours: TimeUtils.durationToDecimal(_nightHoursController.text) ?? 0,
        xcHours: TimeUtils.durationToDecimal(_xcHoursController.text) ?? 0,
        instrumentHours: TimeUtils.durationToDecimal(_instrumentHoursController.text) ?? 0,
        remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
      );

      success = await ref
          .read(logbookNotifierProvider(userId).notifier)
          .updateEntry(entry);
    } else {
      // Create new entry
      final entry = LogbookEntry(
        userId: userId,
        date: _selectedDate,
        depIcao: _depIcaoController.text.toUpperCase(),
        arrIcao: _arrIcaoController.text.toUpperCase(),
        aircraftReg: _aircraftRegController.text.toUpperCase(),
        flightType: _selectedFlightTypes,
        startTime: startDateTime,
        endTime: endDateTime,
        totalHours: _totalHours,
        picHours: TimeUtils.durationToDecimal(_picHoursController.text) ?? 0,
        sicHours: TimeUtils.durationToDecimal(_sicHoursController.text) ?? 0,
        dualHours: TimeUtils.durationToDecimal(_dualHoursController.text) ?? 0,
        dualGivenHours: TimeUtils.durationToDecimal(_dualGivenHoursController.text) ?? 0,
        soloHours: TimeUtils.durationToDecimal(_soloHoursController.text) ?? 0,
        nightHours: TimeUtils.durationToDecimal(_nightHoursController.text) ?? 0,
        xcHours: TimeUtils.durationToDecimal(_xcHoursController.text) ?? 0,
        instrumentHours: TimeUtils.durationToDecimal(_instrumentHoursController.text) ?? 0,
        remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
        status: 'draft', // Saved locally first
      );

      success = await ref
          .read(logbookNotifierProvider(userId).notifier)
          .addEntry(entry);
    }

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Flight updated successfully!' : 'Flight added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } else if (mounted) {
      _showError('Failed to save flight. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Flight' : 'Add Flight'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Step Indicator
          _StepIndicator(
            currentStep: _currentStep,
            onStepTap: _goToStep,
          ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1BasicInfo(
                  formKey: _step1FormKey,
                  selectedDate: _selectedDate,
                  onDateChanged: (date) => setState(() => _selectedDate = date),
                  depIcaoController: _depIcaoController,
                  arrIcaoController: _arrIcaoController,
                  aircraftRegController: _aircraftRegController,
                ),
                _Step2FlightType(
                  formKey: _step2FormKey,
                  selectedTypes: _selectedFlightTypes,
                  onTypesChanged: (types) =>
                      setState(() => _selectedFlightTypes
                        ..clear()
                        ..addAll(types)),
                  startTime: _startTime,
                  endTime: _endTime,
                  onStartTimeChanged: (time) =>
                      setState(() => _startTime = time),
                  onEndTimeChanged: (time) => setState(() => _endTime = time),
                  totalHours: _totalHours,
                ),
                _Step3HoursBreakdown(
                  formKey: _step3FormKey,
                  totalHours: _totalHours,
                  selectedFlightTypes: _selectedFlightTypes,
                  userRole: ref.watch(authNotifierProvider).profile?.pilotType ?? 'student',
                  picHoursController: _picHoursController,
                  sicHoursController: _sicHoursController,
                  dualHoursController: _dualHoursController,
                  dualGivenHoursController: _dualGivenHoursController,
                  soloHoursController: _soloHoursController,
                  nightHoursController: _nightHoursController,
                  xcHoursController: _xcHoursController,
                  instrumentHoursController: _instrumentHoursController,
                  remarksController: _remarksController,
                ),
              ],
            ),
          ),

          // Bottom Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goToStep(_currentStep - 1),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep < 2) {
                                _goToStep(_currentStep + 1);
                              } else {
                                _saveFlight();
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_currentStep < 2 ? 'Next' : 'Save Flight'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final Function(int) onStepTap;

  const _StepIndicator({
    required this.currentStep,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final steps = ['Basic Info', 'Flight Type', 'Time'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            return Expanded(
              child: Container(
                height: 2,
                color: currentStep > index ~/ 2
                    ? AppColors.primary
                    : AppColors.surfaceLight,
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCompleted = currentStep > stepIndex;
          final isCurrent = currentStep == stepIndex;

          return GestureDetector(
            onTap: () => onStepTap(stepIndex),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ==================== STEP 1: BASIC INFO ====================

class _Step1BasicInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final TextEditingController depIcaoController;
  final TextEditingController arrIcaoController;
  final TextEditingController aircraftRegController;

  const _Step1BasicInfo({
    required this.formKey,
    required this.selectedDate,
    required this.onDateChanged,
    required this.depIcaoController,
    required this.arrIcaoController,
    required this.aircraftRegController,
  });

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Flight Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Enter the flight date, route, and aircraft details',
              style: TextStyle(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),

            // Date Picker
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      DateTimeUtils.formatDate(selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),

            const SizedBox(height: 24),

            // Route (DEP / ARR)
            Text(
              'Route',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: depIcaoController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    validator: Validators.validateIcao,
                    decoration: const InputDecoration(
                      labelText: 'Departure',
                      hintText: 'VOMM',
                      counterText: '',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: AppColors.textMuted),
                ),
                Expanded(
                  child: TextFormField(
                    controller: arrIcaoController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    validator: Validators.validateIcao,
                    decoration: const InputDecoration(
                      labelText: 'Arrival',
                      hintText: 'VOBL',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),

            const SizedBox(height: 24),

            // Aircraft Registration
            Text(
              'Aircraft Registration',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: aircraftRegController,
              textCapitalization: TextCapitalization.characters,
              validator: Validators.validateAircraftReg,
              decoration: const InputDecoration(
                labelText: 'Registration',
                hintText: 'VT-ABC',
                prefixIcon: Icon(Icons.flight),
              ),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
          ],
        ),
      ),
    );
  }
}

// ==================== STEP 2: FLIGHT TYPE & HOURS ====================

class _Step2FlightType extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<String> selectedTypes;
  final Function(List<String>) onTypesChanged;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Function(TimeOfDay) onStartTimeChanged;
  final Function(TimeOfDay) onEndTimeChanged;
  final double totalHours;

  const _Step2FlightType({
    required this.formKey,
    required this.selectedTypes,
    required this.onTypesChanged,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.totalHours,
  });

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay initial,
    Function(TimeOfDay) onChanged,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flight Type & Hours',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Select the type of flight and enter block times',
              style: TextStyle(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),

            // Flight Type Selection
            Text(
              'Flight Type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.flightTypes.map((type) {
                final isSelected = selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newTypes = List<String>.from(selectedTypes);
                    if (selected) {
                      // Remove all mutually exclusive types
                      final exclusives = AppConstants.exclusiveTypes[type] ?? [];
                      for (final exclusive in exclusives) {
                        newTypes.remove(exclusive);
                      }
                      newTypes.add(type);
                    } else {
                      newTypes.remove(type);
                    }
                    onTypesChanged(newTypes);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            // Block Times
            Text(
              'Block Times',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimePickerCard(
                    label: 'Block On',
                    time: startTime,
                    onTap: () => _selectTime(context, startTime, onStartTimeChanged),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerCard(
                    label: 'Block Off',
                    time: endTime,
                    onTap: () => _selectTime(context, endTime, onEndTimeChanged),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            // Total Hours Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Total: ${TimeUtils.decimalToHumanDuration(totalHours)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          ],
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== STEP 3: HOURS BREAKDOWN & REMARKS ====================

class _Step3HoursBreakdown extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final double totalHours;
  final List<String> selectedFlightTypes;
  final String userRole; // 'student' or 'instructor'
  final TextEditingController picHoursController;
  final TextEditingController sicHoursController;
  final TextEditingController dualHoursController;
  final TextEditingController dualGivenHoursController;
  final TextEditingController soloHoursController;
  final TextEditingController nightHoursController;
  final TextEditingController xcHoursController;
  final TextEditingController instrumentHoursController;
  final TextEditingController remarksController;

  const _Step3HoursBreakdown({
    required this.formKey,
    required this.totalHours,
    required this.selectedFlightTypes,
    required this.userRole,
    required this.picHoursController,
    required this.sicHoursController,
    required this.dualHoursController,
    required this.dualGivenHoursController,
    required this.soloHoursController,
    required this.nightHoursController,
    required this.xcHoursController,
    required this.instrumentHoursController,
    required this.remarksController,
  });

  @override
  State<_Step3HoursBreakdown> createState() => _Step3HoursBreakdownState();
}

class _Step3HoursBreakdownState extends State<_Step3HoursBreakdown> {
  String? _validationError;
  
  @override
  void initState() {
    super.initState();
    // Auto-populate based on flight types selected
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPopulate());
    
    // Add listeners for real-time validation
    widget.picHoursController.addListener(_validateHours);
    widget.sicHoursController.addListener(_validateHours);
    widget.dualHoursController.addListener(_validateHours);
    widget.dualGivenHoursController.addListener(_validateHours);
    widget.soloHoursController.addListener(_validateHours);
    widget.nightHoursController.addListener(_validateHours);
    widget.xcHoursController.addListener(_validateHours);
    widget.instrumentHoursController.addListener(_validateHours);
  }
  
  void _autoPopulate() {
    final types = widget.selectedFlightTypes;
    final total = widget.totalHours;
    final totalStr = TimeUtils.decimalToInput(total); // H:MM for input fields
    
    // Helper to check if field is empty or "0:00"
    bool isEmpty(TextEditingController controller) {
      final val = TimeUtils.durationToDecimal(controller.text);
      return val == null || val == 0;
    }

    // Only auto-populate if fields are empty/zero
    if (isEmpty(widget.picHoursController) &&
        isEmpty(widget.sicHoursController) &&
        isEmpty(widget.dualHoursController) &&
        isEmpty(widget.soloHoursController)) {
      
      if (types.contains('PIC')) {
        widget.picHoursController.text = totalStr;
      } else if (types.contains('SIC')) {
        widget.sicHoursController.text = totalStr;
      } else if (types.contains('Solo')) {
        widget.soloHoursController.text = totalStr;
        widget.picHoursController.text = totalStr; // Solo implies PIC
      } else if (types.contains('Dual')) {
        widget.dualHoursController.text = totalStr;
      }
    }
    
    if (isEmpty(widget.nightHoursController) && types.contains('Night')) {
      widget.nightHoursController.text = totalStr;
    }
    
    if (isEmpty(widget.xcHoursController) && types.contains('Cross-Country')) {
      widget.xcHoursController.text = totalStr;
    }
    
    // Auto-populate instrument if IMC or Simulated selected
    if (isEmpty(widget.instrumentHoursController) && 
        (types.contains('IMC') || types.contains('Simulated'))) {
      widget.instrumentHoursController.text = totalStr;
    }
  }
  
  void _validateHours() {
    final total = widget.totalHours;
    final totalStr = TimeUtils.decimalToDuration(total);
    
    double val(TextEditingController c) => TimeUtils.durationToDecimal(c.text) ?? 0;

    final pic = val(widget.picHoursController);
    final sic = val(widget.sicHoursController);
    final dual = val(widget.dualHoursController);
    final dualGiven = val(widget.dualGivenHoursController);
    final solo = val(widget.soloHoursController);
    final night = val(widget.nightHoursController);
    final xc = val(widget.xcHoursController);
    final instrument = val(widget.instrumentHoursController);
    
    String? error;
    
    // Individual field validation - each must be ≤ total + epsilon
    const epsilon = 0.01;
    
    if (pic > total + epsilon) {
      error = 'PIC hours cannot exceed total ($totalStr)';
    } else if (sic > total + epsilon) {
      error = 'SIC hours cannot exceed total ($totalStr)';
    } else if (dual > total + epsilon) {
      error = 'Dual Received cannot exceed total ($totalStr)';
    } else if (dualGiven > total + epsilon) {
      error = 'Dual Given cannot exceed total ($totalStr)';
    } else if (solo > total + epsilon) {
      error = 'Solo hours cannot exceed total ($totalStr)';
    } else if (night > total + epsilon) {
      error = 'Night hours cannot exceed total ($totalStr)';
    } else if (xc > total + epsilon) {
      error = 'XC hours cannot exceed total ($totalStr)';
    } else if (instrument > total + epsilon) {
      error = 'Instrument hours cannot exceed total ($totalStr)';
    }
    // Dual Received + Dual Given cannot exceed total (mutually exclusive really, but physically can't do both)
    else if (dual + dualGiven > total + epsilon) {
      error = 'Cannot receive and give instruction simultaneously > total time';
    }
    
    setState(() => _validationError = error);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Total flight time: ${TimeUtils.decimalToDuration(widget.totalHours)}',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              'Enter detailed time breakdown (each must be ≤ total)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ).animate().fadeIn(delay: 150.ms),
            
            // Validation error display
            if (_validationError != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().shake(),
            
            const SizedBox(height: 24),

            // Role Time
            Text(
              'Role Time',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Always show PIC & Solo
            Row(
              children: [
                Expanded(
                  child: _HoursFieldWithMax(
                    label: 'PIC',
                    controller: widget.picHoursController,
                    color: AppColors.accent,
                    maxHours: widget.totalHours,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _HoursFieldWithMax(
                    label: 'Solo',
                    controller: widget.soloHoursController,
                    color: Colors.purple,
                    maxHours: widget.totalHours,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
            
            // Add SIC & Dual when NOT solo
            if (!widget.selectedFlightTypes.contains('Solo')) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HoursFieldWithMax(
                      label: 'SIC',
                      controller: widget.sicHoursController,
                      color: Colors.orange,
                      maxHours: widget.totalHours,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HoursFieldWithMax(
                      label: 'Dual',
                      controller: widget.dualHoursController,
                      color: AppColors.primary,
                      maxHours: widget.totalHours,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 220.ms),
            ],
            
            const SizedBox(height: 24),

            // Condition & Instrument
            Text(
              'Conditions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HoursFieldWithMax(
                    label: 'Night',
                    controller: widget.nightHoursController,
                    color: Colors.indigo,
                    maxHours: widget.totalHours,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _HoursFieldWithMax(
                    label: 'Cross-Country',
                    controller: widget.xcHoursController,
                    color: AppColors.warning,
                    maxHours: widget.totalHours,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 280.ms),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _HoursFieldWithMax(
                    label: 'Instrument',
                    controller: widget.instrumentHoursController,
                    color: Colors.deepPurple,
                    maxHours: widget.totalHours,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()), // Empty space for balance
              ],
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 32),

            // Remarks
            Text(
              'Remarks',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.remarksController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'E.g., IFR route prep, training maneuvers...',
                alignLabelWithHint: true,
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 24),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Flight Time'),
                      Text(
                        TimeUtils.decimalToHumanDuration(widget.totalHours),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Flight will be saved locally and synced when online',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

class _HoursFieldWithMax extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final double maxHours;

  const _HoursFieldWithMax({
    required this.label,
    required this.controller,
    required this.color,
    required this.maxHours,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with max in smaller text below
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '≤${TimeUtils.decimalToDuration(maxHours)}',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            isDense: true,
            hintText: '0:00',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            errorMaxLines: 1,
            errorStyle: const TextStyle(fontSize: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color, width: 2),
            ),
            filled: true,
            fillColor: color.withOpacity(0.05),
          ),
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          validator: (value) {
            if (value == null || value.isEmpty) return null;
            if (!TimeUtils.isValidDuration(value)) {
              return 'Use HH:MM';
            }
            final hours = TimeUtils.durationToDecimal(value);
            if (hours == null) return 'Invalid';
            if (hours < 0) return '≥ 0:00';
            if (hours > maxHours + 0.01) { // Small epsilon for float comparison
              return '> ${TimeUtils.decimalToDuration(maxHours)}';
            }
            return null;
          },
          inputFormatters: [
            // Optional: Add a formatter here if we want to enforce ":" automatically
            // For now, freeform with validation is enough
          ],
        ),
      ],
    );
  }
}

class _HoursField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;

  const _HoursField({
    required this.label,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: Validators.validateHours,
          decoration: InputDecoration(
            hintText: '0.0',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
