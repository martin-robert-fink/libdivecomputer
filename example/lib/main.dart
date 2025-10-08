import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:libdivecomputer/libdivecomputer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libdivecomputer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DiveComputerPage(),
    );
  }
}

class DiveComputerPage extends StatefulWidget {
  const DiveComputerPage({super.key});

  @override
  State<DiveComputerPage> createState() => _DiveComputerPageState();
}

class _DiveComputerPageState extends State<DiveComputerPage> {
  final _libdc = Libdivecomputer.instance;

  List<String> _vendors = [];
  String? _selectedVendor;

  List<DescriptorInfo> _devices = [];
  DescriptorInfo? _selectedDevice;

  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;

  final List<DiveData> _dives = [];
  DiveData? _selectedDive;

  String _status = 'Ready';
  double _progress = 0.0;
  bool _isScanning = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() => _status = 'Loading vendors...');

    final vendors = await _libdc.getVendors();

    setState(() {
      _vendors = vendors;
      _status = 'Select a vendor';
    });
  }

  Future<void> _loadDevices(String vendor) async {
    setState(() => _status = 'Loading devices for $vendor...');

    final devices = await _libdc.getDescriptorsByVendor(vendor);

    // Filter for BLE-capable devices
    final bleDevices = devices.where((d) => d.supportsBLE).toList();

    setState(() {
      _devices = bleDevices;
      _selectedDevice = null;
      _status = bleDevices.isEmpty
          ? 'No BLE devices found for $vendor'
          : 'Select a dive computer';
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    // Check Bluetooth
    final isEnabled = await _libdc.isBluetoothEnabled();
    if (!isEnabled) {
      setState(() => _status = 'Please enable Bluetooth');
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning for dive computers...';
      _scanResults.clear();
    });

    try {
      // Known dive computer manufacturer names for filtering
      const diveComputerNames = [
        'Petrel', 'Perdix', 'Teric', 'Peregrine', 'Shearwater',
        'Suunto', 'EON', 'D5', 'Vyper', 'Zoop',
        'Mares', 'Smart', 'Genius', 'Quad', 'Puck',
        'Oceanic', 'Pro Plus', 'Geo', 'Atom', 'VT',
        'Aqua Lung', 'i300', 'i200', 'i750',
        'Cressi', 'Leonardo', 'Giotto', 'Newton',
        'Scubapro', 'G2', 'Aladin', 'Galileo',
        'Ratio', 'iX3M', 'iDive',
        'Heinrichs Weikamp', 'OSTC',
      ];

      // Set up scan result listener BEFORE starting scan
      final scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          if (results.isNotEmpty) {
            // Filter for dive computers only
            final filteredResults = results.where((result) {
              final name = result.device.platformName;
              if (name.isEmpty) return false;
              
              // Check if name contains any known manufacturer/model
              return diveComputerNames.any(
                (dcName) => name.toUpperCase().contains(dcName.toUpperCase())
              );
            }).toList();

            setState(() {
              _scanResults = filteredResults;
              _status = 'Found ${filteredResults.length} dive computer(s)';
            });
          }
        },
        onError: (e) {
          debugPrint('Scan error: $e');
          setState(() => _status = 'Scan error: $e');
        },
      );

      // Start scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      
      // Cancel subscription
      await scanSubscription.cancel();

      setState(() {
        _isScanning = false;
        _status = _scanResults.isEmpty
            ? 'No dive computers found'
            : 'Select a dive computer to connect';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _status = 'Scan failed: $e';
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _status = 'Connecting to ${device.platformName}...');

    try {
      // DON'T connect with flutter_blue_plus - let native plugin do it
      // The native plugin needs to connect with its own CBCentralManager
      // to receive delegate callbacks
      
      // Just call setupBLEDevice - it will handle the connection
      await _libdc.setupBLEDevice(device);

      setState(() {
        _connectedDevice = device;
        _status = 'Connected to ${device.platformName}';
      });
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  Future<void> _downloadDives() async {
    if (_selectedDevice == null || _connectedDevice == null) {
      setState(() => _status = 'Please connect to a device first');
      return;
    }

    setState(() {
      _isDownloading = true;
      _status = 'Opening device...';
      _progress = 0.0;
      _dives.clear();
    });

    try {
      // Open device
      final openStatus = await _libdc.openDevice(
        vendor: _selectedDevice!.vendor,
        product: _selectedDevice!.product,
        deviceId: _connectedDevice!.remoteId.toString(),
      );

      if (openStatus != StatusCode.success) {
        setState(() {
          _status = 'Failed to open device: ${openStatus.description}';
          _isDownloading = false;
        });
        return;
      }

      setState(() => _status = 'Downloading dives...');

      // Download dives with callbacks
      final downloadStatus = await _libdc.downloadDives(
        onProgress: (current, total) {
          setState(() {
            _progress = total > 0 ? current / total : 0.0;
            _status = 'Downloading dive $current of $total';
          });
        },
        onDive: (dive) {
          setState(() {
            _dives.add(dive);
          });
          debugPrint('Downloaded dive: ${dive.number}');
        },
        onDeviceInfo: (info) {
          debugPrint('Device info: $info');
        },
        onLog: (message) {
          debugPrint('LibDC: $message');
        },
      );

      // Close device
      await _libdc.closeDevice();

      setState(() {
        _isDownloading = false;
        _status = downloadStatus == StatusCode.success
            ? 'Downloaded ${_dives.length} dives'
            : 'Download failed: ${downloadStatus.description}';
        _progress = 1.0;
      });
    } catch (e) {
      await _libdc.closeDevice();

      setState(() {
        _isDownloading = false;
        _status = 'Download error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Libdivecomputer Demo'),
      ),
      body: Row(
        children: [
          // Left panel - Controls
          Expanded(
            flex: 1,
            child: _buildControlPanel(),
          ),

          const VerticalDivider(width: 1),

          // Right panel - Dive list and details
          Expanded(
            flex: 2,
            child: _buildDivePanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  if (_isDownloading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _progress),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Vendor selection
          const Text('1. Select Vendor:'),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedVendor,
            isExpanded: true,
            hint: const Text('Choose vendor'),
            items: _vendors.map((vendor) {
              return DropdownMenuItem(
                value: vendor,
                child: Text(vendor),
              );
            }).toList(),
            onChanged: (vendor) {
              setState(() {
                _selectedVendor = vendor;
                _selectedDevice = null;
              });
              if (vendor != null) {
                _loadDevices(vendor);
              }
            },
          ),

          const SizedBox(height: 24),

          // Device selection
          const Text('2. Select Dive Computer:'),
          const SizedBox(height: 8),
          DropdownButton<DescriptorInfo>(
            value: _selectedDevice,
            isExpanded: true,
            hint: const Text('Choose device'),
            items: _devices.map((device) {
              return DropdownMenuItem(
                value: device,
                child: Text(device.product),
              );
            }).toList(),
            onChanged: (device) {
              setState(() => _selectedDevice = device);
            },
          ),

          const SizedBox(height: 24),

          // Scan button
          const Text('3. Scan for BLE Devices:'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed:
                _selectedDevice == null || _isScanning ? null : _startScan,
            icon: Icon(
              _isScanning ? Icons.hourglass_empty : Icons.bluetooth_searching,
            ),
            label: Text(_isScanning ? 'Scanning...' : 'Scan'),
          ),

          const SizedBox(height: 16),

          // Scan results
          if (_scanResults.isNotEmpty) ...[
            const Text('Found Devices:'),
            const SizedBox(height: 8),
            ..._scanResults.map((result) {
              return Card(
                child: ListTile(
                  title: Text(
                    result.device.platformName.isEmpty
                        ? 'Unknown Device'
                        : result.device.platformName,
                  ),
                  subtitle: Text(result.device.remoteId.toString()),
                  trailing: Text('${result.rssi} dBm'),
                  onTap: () => _connectToDevice(result.device),
                  selected:
                      _connectedDevice?.remoteId == result.device.remoteId,
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // Download button
          const Text('4. Download Dives:'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _connectedDevice == null || _isDownloading
                ? null
                : _downloadDives,
            icon: const Icon(Icons.download),
            label: const Text('Download Dives'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivePanel() {
    if (_dives.isEmpty) {
      return const Center(
        child: Text('No dives downloaded yet'),
      );
    }

    return Row(
      children: [
        // Dive list
        Expanded(
          flex: 1,
          child: ListView.builder(
            itemCount: _dives.length,
            itemBuilder: (context, index) {
              final dive = _dives[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${dive.number}'),
                ),
                title: Text('Dive #${dive.number}'),
                subtitle: Text(
                  '${dive.dateTime.toString().split('.')[0]}\n'
                  '${dive.formattedDuration} • ${dive.maxDepth.toStringAsFixed(1)}m',
                ),
                isThreeLine: true,
                selected: _selectedDive == dive,
                onTap: () {
                  setState(() => _selectedDive = dive);
                },
              );
            },
          ),
        ),

        const VerticalDivider(width: 1),

        // Dive details
        Expanded(
          flex: 2,
          child: _selectedDive == null
              ? const Center(child: Text('Select a dive to view details'))
              : _buildDiveDetails(_selectedDive!),
        ),
      ],
    );
  }

  Widget _buildDiveDetails(DiveData dive) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dive #${dive.number}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Date & Time',
            dive.dateTime.toString().split('.')[0],
          ),
          _buildDetailCard('Duration', dive.formattedDuration),
          _buildDetailCard(
            'Max Depth',
            '${dive.maxDepth.toStringAsFixed(1)} m',
          ),
          if (dive.avgDepth != null)
            _buildDetailCard(
              'Avg Depth',
              '${dive.avgDepth!.toStringAsFixed(1)} m',
            ),
          if (dive.minTemperature != null)
            _buildDetailCard(
              'Min Temperature',
              '${dive.minTemperature!.toStringAsFixed(1)} °C',
            ),
          if (dive.maxTemperature != null)
            _buildDetailCard(
              'Max Temperature',
              '${dive.maxTemperature!.toStringAsFixed(1)} °C',
            ),
          if (dive.startPressure != null && dive.endPressure != null)
            _buildDetailCard(
              'Pressure',
              '${dive.startPressure!.toStringAsFixed(0)} → ${dive.endPressure!.toStringAsFixed(0)} bar',
            ),
          if (dive.diveMode != null)
            _buildDetailCard('Dive Mode', dive.diveMode!),
          const SizedBox(height: 16),
          Text(
            'Profile (${dive.samples.length} samples)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (dive.samples.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: dive.samples.length,
                itemBuilder: (context, index) {
                  final sample = dive.samples[index];
                  return ListTile(
                    dense: true,
                    title: Text('Time: ${sample.time}s'),
                    subtitle: Text(
                      'Depth: ${sample.depth?.toStringAsFixed(1) ?? "N/A"}m, '
                      'Temp: ${sample.temperature?.toStringAsFixed(1) ?? "N/A"}°C',
                    ),
                  );
                },
              ),
            ),
          ] else
            const Text('No samples available'),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(value),
          ],
        ),
      ),
    );
  }
}
