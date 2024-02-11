import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms.dart';
import 'google_auth.dart';

// class SpreadsheetProvider extends ChangeNotifier {
// }

class SpreadsheetProvider {
  static final spreadsheet =
      NotifierProvider<Notifier<Spreadsheet?>, Spreadsheet?>(
          () => _spreadsheetNotifier);

  static final spreadsheetLastId = Provider<int?>((ref) {
    final ss = ref.watch(spreadsheet);
    return ss != null ? SpreadsheetProvider.lastId(ss) : null;
  });

  static final SpreadsheetNotifier _spreadsheetNotifier = SpreadsheetNotifier();

  bool _readPreferences = false;
  String? _id;
  late final SheetsApi _api;
  late Spreadsheet _spreadsheet;

  Future<Spreadsheet> getSpreadsheet() async {
    final ss = (await isSheetAvailable())
        ? await _api.spreadsheets
            .get(_id!, includeGridData: true)
            .onError<ApiRequestError>((error, __) async {
            if (error is DetailedApiRequestError && error.status == 404)
              return await createSpreadsheet();
            throw error;
          })
        : await createSpreadsheet();

    print(ss.spreadsheetUrl);
    print(ss.properties?.toJson());
    print(ss.toJson());

    _spreadsheet = ss;
    _spreadsheetNotifier.state = _spreadsheet;
    return ss;
  }

  Future<Spreadsheet> createSpreadsheet() async {
    Spreadsheet ss = Spreadsheet(
      properties: SpreadsheetProperties(
        title: "HipaGora.RawData ${DateTime.now()}",
        timeZone: 'Europe/Belgrade',
        locale: 'hr_HR',
      ),
      sheets: [
        Sheet(
          data: [
            GridData(
              startColumn: 0,
              startRow: 1,
              rowData: [
                //Row with titles
                buildRow(SmsModel.titles),
                //Row with filters
                buildRow(SmsModel.titles, stringifier: (s) => "\t⧨"),
              ],
              columnMetadata: SmsModel.titles
                  .map((t) => DimensionProperties(
                        hiddenByUser: 'Raw' == t,
                      ))
                  .toList(growable: false),
            ),
          ],
          properties: SheetProperties(
            title: "Raw Data",
            sheetType: "GRID",
            gridProperties: GridProperties(
              rowCount: 1700,
              columnCount: SmsModel.titles.length,
              frozenRowCount: 3,
              frozenColumnCount: 4,
            ),
          ),
        ),
      ],
    );
    ss = await _api.spreadsheets.create(ss);
    // var req = BatchUpdateSpreadsheetRequest(
    //   includeSpreadsheetInResponse: true,
    //   responseIncludeGridData: true,
    //   requests: [
    //     Request(
    //       addProtectedRange: AddProtectedRangeRequest(
    //         protectedRange: ProtectedRange(
    //             description: "Please do not change the raw data.",
    //             warningOnly: false,
    //             editors: Editors(domainUsersCanEdit: false, users: ['API']),
    //             range: GridRange(
    //               sheetId: ss.sheets![0].properties!.sheetId!,
    //               startColumnIndex: 1,
    //               endColumnIndex: SmsModel.titles.length,
    //               startRowIndex: 1,
    //               endRowIndex: 30,
    //             ),
    //             unprotectedRanges: [
    //               // TODO Define columns with comments
    //             ]),
    //       ),
    //     ),
    //   ],
    // );
    // ss = (await _api.spreadsheets.batchUpdate(req, ss.spreadsheetId!))
    //     .updatedSpreadsheet!;
    _setId(ss);
    return ss;
  }

  Future<bool> isSheetAvailable() async {
    return (_readPreferences && _id != null) ||
        await SharedPreferences.getInstance().then((sp) async {
          await _initApi();
          _id = sp.getString("spreadsheet.id");
          _readPreferences = true;
          return _id != null;
        });
  }

  _setId(Spreadsheet? ss) {
    var id = ss?.spreadsheetId! ?? "";
    var url = ss?.spreadsheetUrl! ?? "";
    if (_id == id) return;
    _id = id;
    SharedPreferences.getInstance().then((sp) {
      sp.setString("spreadsheet.id", id);
      sp.setString("spreadsheet.url", url);
    });
  }

  clean() {
    _setId(null);
  }

  Future<void> _initApi() async {
    _api = await GoogleAuthProvider().sheetsApi;
  }

  Future<void> addRow(SmsModel sms) async {
    var response = await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          includeSpreadsheetInResponse: true,
          responseIncludeGridData: true,
          requests: [
            Request(
              appendCells: AppendCellsRequest(
                sheetId: _spreadsheet.sheets![0].properties!.sheetId!,
                fields: "*",
                rows: [
                  buildRow(sms.getRow()),
                ],
              ),
            ),
          ],
        ),
        _id!);
    _spreadsheet = response.updatedSpreadsheet!;
    _spreadsheetNotifier.state = _spreadsheet;
  }

  Future<void> addRows(Iterable<SmsModel> list) async {
    final rows =
        list.map((sms) => buildRow(sms.getRow())).toList(growable: false);

    var response = await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          includeSpreadsheetInResponse: true,
          responseIncludeGridData: true,
          requests: [
            Request(
              appendCells: AppendCellsRequest(
                sheetId: _spreadsheet.sheets![0].properties!.sheetId!,
                fields: "*",
                rows: rows,
              ),
            ),
          ],
        ),
        _id!);
    _spreadsheet = response.updatedSpreadsheet!;
    _spreadsheetNotifier.state = _spreadsheet;
  }

  static RowData buildRow(List cells,
      {String? Function(String?)? stringifier}) {
    stringCell(String? cell) => CellData(
        userEnteredValue: ExtendedValue(stringValue: cell),
        userEnteredFormat: CellFormat(
          verticalAlignment: "MIDDLE",
          horizontalAlignment: (cell?.length ?? 9) < 4 ? "RIGHT" : "LEFT",
        ));

    var cellData = stringifier != null
        ? (cell) => stringCell(stringifier(cell?.toString()))
        : (cell) => switch (cell.runtimeType) {
              Null => stringCell(null),
              String => stringCell(cell),
              DateTime => CellData(
                  userEnteredValue: ExtendedValue(
                    numberValue: cell.millisecondsSinceEpoch / 86400000 + 25569,
                  ),
                  userEnteredFormat: CellFormat(
                    verticalAlignment: "MIDDLE",
                    horizontalAlignment: "RIGHT",
                    numberFormat: NumberFormat(
                      type: "DATE_TIME",
                      pattern: "yyyy.MM.dd\nHH:mm:ss",
                    ),
                  )),
              int => CellData(
                  userEnteredValue: ExtendedValue(numberValue: cell.toDouble()),
                  userEnteredFormat: CellFormat(
                    horizontalAlignment: "RIGHT",
                    verticalAlignment: "MIDDLE",
                    numberFormat: NumberFormat(
                      type: "NUMBER",
                      pattern: "#00",
                    ),
                  )),
              double => CellData(
                  userEnteredValue: ExtendedValue(numberValue: cell),
                  userEnteredFormat: CellFormat(
                    horizontalAlignment: "RIGHT",
                    verticalAlignment: "MIDDLE",
                    numberFormat: NumberFormat(
                      type: "NUMBER",
                      pattern: "#0.00",
                    ),
                  )),
              _ => stringCell(cell?.toString())
            };

    return RowData(
        values: cells
            .map((cell) => cellData(cell))
            // .map((cell) => CellData(userEnteredValue: extendedValue(cell)))
            .toList(growable: false));
  }

  static int lastId(Spreadsheet ss) {
    // SmsModel.titles
    // var id = ss.sheets![0].data![0].rowData![0].values![0].formattedValue;
    final idColumn = SmsModel.titles.indexOf(SmsModel.smsIdTitle);
    return ss.sheets?[0].data?[0].rowData
            ?.skip(3)
            .takeWhile((row) => row.values![0].formattedValue != null)
            .lastOrNull
            ?.values?[idColumn]
            .effectiveValue
            ?.numberValue
            ?.toInt() ??
        0;
  }
}

class SpreadsheetNotifier extends Notifier<Spreadsheet?> {
  @override
  Spreadsheet? build() => null;
}
