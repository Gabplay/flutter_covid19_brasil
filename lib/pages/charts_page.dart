import 'package:charts_flutter/flutter.dart' as charts;
import 'package:date_format/date_format.dart' as dt;
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:covid_19_brasil/widgets/line_chart.dart';
import 'package:covid_19_brasil/model/states.dart';
import 'package:vibration/vibration.dart';

class ChartsPage extends StatefulWidget {
  @override
  _ChartsPageState createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  String chartIndex = 'Total';
  bool showChart = false, showBarChart = false;
  DateTime initialInfectionDayBR = DateTime(2020, 02, 25);
  DateTime initialDate = DateTime.now().subtract(new Duration(days: 30));
  DateTime finalDate = DateTime.now();
  DateTime selectedInitialDate = DateTime.now().subtract(new Duration(days: 30));
  DateTime selectedFinalDate = DateTime.now();

  List<TimeSeriesCovid> lineTotalCases = [], lineNewCases = [], lineTotalDeaths = [], lineNewDeaths = [], lineRecovered = [];
  List<TimeSeriesCovidDouble> lineFatality = [];
  List<charts.Series<dynamic, DateTime>> lineChart = [];

  String _selectedType = 'Brasil', _selectedRegion = 'TOTAL', _selectedLabel = '', _pointSelected, errorMsg;
  List<String> _locations = ['Brasil', 'Estados'], _locationsStates = [], _locationsRegions = [];
  List fileDataStates;
  DateTime _timeSelected;
  var lineChartWidget;

  void initState() {  
    super.initState();
    downloadFiles();
  }

  void downloadFiles() async{
    fetchCsvFile('https://raw.githubusercontent.com/wcota/covid19br/master/cases-brazil-states.csv', 'cases-brazil-states.csv');
    // Cities file is too big and taking too long to load
    // fetchCsvFile('https://raw.githubusercontent.com/wcota/covid19br/master/cases-brazil-cities-time_changesOnly.csv', 'cases-brazil-cities-time.csv');
  }

  fetchCsvFile(link, filename) async {      
    final response = await http.get(link);
    
    if (response.statusCode == 200) {
      var txt = response.body;
      _createChart(txt, filename);
    } else {
      setState(() {
        errorMsg = 'Erro (' + response.statusCode.toString() + '): ' + response.body;
      });
      throw Exception('Erro ao carregar informações.');
    }
  }

  List initStates(txt){
    fileDataStates = txt;
    states.forEach((uf, state){
      _locationsStates.add(state.name + ' - ' + uf);
      return true;
    });
    return _locationsStates;
  }

  void _createChart(txt, filename) async{ 
    List states = initStates(txt.split('\n'));
    if(mounted){
      setState(() {
        _locationsStates = states;
      });
      updateChartInfo();
    }
    changeChart(chartIndex);
  }

  void updateChartInfo(){
    int count = 1, index;
    List<TimeSeriesCovid> totalCases = [], newCases = [], totalDeaths = [], newDeaths = [], recoveredCases = [];
    List<TimeSeriesCovidDouble> fatality = [];
    List fileData, columnTitles;

    switch(_selectedType){
      case 'Brasil':
        fileData = fileDataStates;
        break;
      case 'Estados':
        fileData = fileDataStates;
        if(_selectedRegion != ''){
          _selectedLabel = states[_selectedRegion.split('-')[1].trim()].name + ' - ' + _selectedRegion.split('-')[1].trim();
          _selectedRegion = _selectedRegion.split('-')[1].trim();
        }
      break;
    }

    columnTitles = fileData[0].split(",");
    index = columnTitles.indexOf("state");
    
    if(_selectedRegion != ''){
      fileData.forEach((strRow){
        if(strRow == ""){
          return false;
        }

        var info = strRow.split(",");
        if(count > 1){
          var infoDate = DateTime.parse(info[columnTitles.indexOf('date')]);

          if((info[index] == _selectedRegion) && 
              ((infoDate.isAfter(selectedInitialDate) && infoDate.isBefore(selectedFinalDate)) || 
              (infoDate.isAtSameMomentAs(selectedInitialDate) || infoDate.isAtSameMomentAs(selectedFinalDate)))){
            double fatalRatio = 0;
            if(int.parse(info[columnTitles.indexOf('deaths')]) > 0){
              fatalRatio = (int.parse(info[columnTitles.indexOf('deaths')]) / int.parse(info[columnTitles.indexOf('totalCases')]) * 100);
              String fatalStr = fatalRatio.toStringAsFixed(2);
              fatalRatio = double.parse(fatalStr);
            }

            String date = info[columnTitles.indexOf('date')];
            if(int.parse(info[columnTitles.indexOf('totalCases')]) > 0) totalCases.add(new TimeSeriesCovid(DateTime.parse(date), int.parse(info[columnTitles.indexOf('totalCases')])));
            if(int.parse(info[columnTitles.indexOf('newCases')]) > 0) newCases.add(new TimeSeriesCovid(DateTime.parse(date), int.parse(info[columnTitles.indexOf('newCases')])));
            if(columnTitles.indexOf('recovered') != -1){
              if(info[columnTitles.indexOf('recovered')] != '' && info[columnTitles.indexOf('recovered')] != '0') recoveredCases.add(new TimeSeriesCovid(DateTime.parse(date), int.parse(info[columnTitles.indexOf('recovered')])));
            }
            if(int.parse(info[columnTitles.indexOf('deaths')]) > 0) totalDeaths.add(new TimeSeriesCovid(DateTime.parse(date), int.parse(info[columnTitles.indexOf('deaths')])));
            if(int.parse(info[columnTitles.indexOf('newDeaths')]) > 0) newDeaths.add(new TimeSeriesCovid(DateTime.parse(date), int.parse(info[columnTitles.indexOf('newDeaths')])));
            if(int.parse(info[columnTitles.indexOf('deaths')]) > 0) fatality.add(new TimeSeriesCovidDouble(DateTime.parse(date), fatalRatio));
            return true;
          }
        }
        count++;
        return false;
      });
      setState(() {
        lineTotalCases = totalCases;
        lineNewCases = newCases;
        lineRecovered = recoveredCases;
        lineTotalDeaths = totalDeaths;
        lineNewDeaths = newDeaths;
        lineFatality = fatality;
      });
    }
  }

  getSuggestions(pattern) async{
    if(pattern.length > 0){
      return _locationsRegions.where((i) => i.toLowerCase().contains(pattern.toLowerCase())).toList();
    } else{
      return [];
    }
  }

  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;
    DateTime time;
    String selected;

    if (selectedDatum.isNotEmpty) {
      time = selectedDatum.first.datum.time;
      selectedDatum.forEach((charts.SeriesDatum datumPair) {
        if(chartIndex == 'Letalidade'){
          selected = datumPair.datum.ratio.toString() + '%';
        } else{
          selected = formatted(datumPair.datum.cases.toString());
        }
      });
      Vibration.vibrate(duration: 10, amplitude: 255);

      setState(() {
        _timeSelected = time;
        _pointSelected = selected;
      });

      ToolTipMgr.setTitle({
        'title': selected,
        'subTitle': dt.formatDate(_timeSelected, [dt.dd, '/', dt.mm, '/', dt.yyyy])
      });
    }
  }

  changeChart(chartName){
    var chartColor = charts.MaterialPalette.red.shadeDefault;
    var chartData = lineTotalCases;
    var showBars = false;

    switch(chartName){
      case 'Novos Casos':
        chartData = lineNewCases;
        chartColor = charts.MaterialPalette.blue.shadeDefault;
        showBars = true;
      break;
      case 'Recuperados':
        chartData = lineRecovered;
        chartColor = charts.MaterialPalette.green.shadeDefault;
      break;
      case 'Fatais':
        chartData = lineTotalDeaths;
        chartColor = charts.MaterialPalette.indigo.shadeDefault;
      break;
      case 'Novos Óbitos':
        chartData = lineNewDeaths;
        chartColor = charts.MaterialPalette.blue.shadeDefault;
        showBars = true;
      break;
      case 'Letalidade':
        chartColor = charts.MaterialPalette.cyan.shadeDefault;
      break;
    }
    
    if(chartName == 'Letalidade'){
      lineChart = [
        charts.Series<TimeSeriesCovidDouble, DateTime>(
        id: chartName,
        colorFn: (_, __) => chartColor,
        domainFn: (TimeSeriesCovidDouble register, _) => register.time,
        measureFn: (TimeSeriesCovidDouble register, _) => register.ratio,
        data: lineFatality,
      )];
    } else{
      lineChart = [
        charts.Series<TimeSeriesCovid, DateTime>(
        id: chartName,
        colorFn: (_, __) => chartColor,
        domainFn: (TimeSeriesCovid register, _) => register.time,
        measureFn: (TimeSeriesCovid register, _) => register.cases,
        data: chartData,
      )];
    }

    setState(() {
      _timeSelected = null;
      showBarChart = showBars;
      if(_selectedRegion != ''){
        lineChartWidget = new charts.TimeSeriesChart(
          lineChart,
          animate: false,
          defaultRenderer: (showBarChart ? new charts.BarRendererConfig<DateTime>() : new charts.LineRendererConfig(includePoints: true, includeLine: true)),
          selectionModels: [
            new charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: _onSelectionChanged,
            )
          ],
          behaviors: [
            charts.LinePointHighlighter(symbolRenderer: CustomCircleSymbolRenderer())
          ],
        );
      }
      chartIndex = chartName;
      showChart = true;
    });
  }

  String formatted(String str){
    int val = int.parse(str);
    return new NumberFormat.decimalPattern('pt').format(val).toString();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
      child:
      Container(
      child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: 
                <Widget>[ 
                  DropdownButton(
                    value: _selectedType,
                    onChanged: (newValue) {
                      if(newValue == 'Brasil' && newValue != _selectedType){
                        setState(() {
                          _selectedType = newValue;
                          _selectedRegion = 'TOTAL';
                          _selectedLabel = '';
                        });
                        updateChartInfo();
                        changeChart('Total');
                      } 
                      else if(newValue != _selectedType){
                        setState(() {
                          _selectedType = newValue;
                          _selectedRegion = '';
                          _selectedLabel = '';
                          _locationsRegions = _locationsStates;
                          lineChartWidget = Text('Pesquise uma região para mais detalhes', textAlign: TextAlign.center);
                        });
                      }
                    },
                    items: _locations.map((location) {
                      return DropdownMenuItem(
                        child: new Text(location),
                        value: location,
                      );
                    }).toList(),
                  ),
                  RaisedButton(
                    color: Colors.blue,
                    child: Row( // Replace with a Row for horizontal icon + text
                      children: <Widget>[
                        Icon(Icons.date_range, color: Colors.white,),
                        Padding(
                          padding: const EdgeInsets.only(left:8.0),
                          child: Text("Inicial", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                    onPressed: (){
                      showDatePicker(context: context, currentDate: DateTime.now(), initialDatePickerMode: DatePickerMode.day,
                        initialDate: selectedInitialDate, firstDate: initialInfectionDayBR, lastDate: selectedFinalDate, 
                        cancelText: "Cancelar", confirmText: "Confirmar").then((value){
                          if(value != selectedInitialDate && value != null){
                            setState(() {
                              selectedInitialDate = value;
                            });
                            updateChartInfo();
                            changeChart(chartIndex);
                          }
                        });
                    }
                  ),
                  RaisedButton(
                    color: Colors.blue,
                    child: Row( // Replace with a Row for horizontal icon + text
                      children: <Widget>[
                        Icon(Icons.date_range, color: Colors.white,),
                        Padding(
                          padding: const EdgeInsets.only(left:8.0),
                          child: Text("Final", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                    onPressed: (){
                     showDatePicker(context: context, currentDate: DateTime.now(), initialDatePickerMode: DatePickerMode.day,
                        initialDate: selectedFinalDate, firstDate: selectedInitialDate, lastDate: DateTime.now(), 
                        cancelText: "Cancelar", confirmText: "Confirmar").then((value){
                          if(value != selectedFinalDate && value != null){
                            setState(() {
                              selectedFinalDate = value;  
                            });
                            updateChartInfo();
                            changeChart(chartIndex);
                          }
                        });
                    }
                  ),
              ])
            ),
                
          if(_selectedType != 'Brasil')
          (Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child:
              Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[ 
                Expanded( // wrap your Column in Expanded
                  child: Column(
                  children: <Widget>[
                    TypeAheadFormField(
                    textFieldConfiguration: TextFieldConfiguration(
                      autofocus: false,
                      style: DefaultTextStyle.of(context).style.copyWith(
                        fontStyle: FontStyle.normal
                      ),
                      decoration: InputDecoration(
                        labelText: 'Pesquisar:'
                      )
                    ),
                    suggestionsCallback: (pattern) async {
                      return await getSuggestions(pattern);
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        leading: Icon(Icons.location_on),
                        title: Text(suggestion)
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      setState(() {
                        if(suggestion != _selectedRegion){
                          _selectedRegion = suggestion;
                        }
                      });
                      updateChartInfo();
                      changeChart('Total');
                    },
                    hideOnError: true,
                    hideSuggestionsOnKeyboardHide: true,
                    noItemsFoundBuilder: (BuildContext context){
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Nenhuma localidade encontrada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).disabledColor, fontSize: 18.0),
                        ),
                      );
                    },
                )],
              ))])
            )
          ),
            
          if(_selectedRegion != '') (  
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: 
                <Widget>[ 
                  if(lineTotalCases.length > 0) ChartButtonWidget(chartName: 'Total', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 80),
                  if(lineNewCases.length > 0) ChartButtonWidget(chartName: 'Novos Casos', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 120),
                  if(lineRecovered.length > 0) ChartButtonWidget(chartName: 'Recuperados', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 120),
                ]),
            )
          ),
          if(_selectedRegion != '') (  
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: 
                <Widget>[ 
                  if(lineTotalDeaths.length > 0) ChartButtonWidget(chartName: 'Fatais', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 80),
                  if(lineNewDeaths.length > 0) ChartButtonWidget(chartName: 'Novos Óbitos', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 120),
                  if(lineFatality.length > 0) ChartButtonWidget(chartName: 'Letalidade', chartIndex: this.chartIndex, changeChart: this.changeChart, btnSize: 120),
                ]),
            )
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical:12.0),
            child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[ 
                  Text('Intervalo: ' + dt.formatDate(selectedInitialDate, [dt.dd, '/', dt.mm, '/', dt.yyyy]) +
                      ' até '+ dt.formatDate(selectedFinalDate, [dt.dd, '/', dt.mm, '/', dt.yyyy]))
                ]
            ),
          ),

          if(errorMsg != null)
          (AlertDialog(
            title: Text('Aviso'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(errorMsg),
                  Text('Verifique sua conexão com a Internet ou tente novamente mais tarde.'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('OK'),
                onPressed: () {
                  setState(() {
                    errorMsg = null;
                  });
                },
              ),
            ],
          )),

          if(_selectedRegion != 'TOTAL') (
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(_selectedLabel, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))
            )
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: showChart ? 
              (lineChartWidget) :
              (Center(
                  child: Text(
                    "Carregando os dados...",
                    textAlign: TextAlign.center,
                  ),
                )
              ), 
            )),

            if(_selectedRegion != '') (
              Center(
                child:
                  Padding(
                  padding: new EdgeInsets.all(16.0),
                  child: Text(
                    _timeSelected != null ? 
                    _pointSelected + " " + chartIndex + " em " + dt.formatDate(_timeSelected, [dt.dd, '/', dt.mm, '/', dt.yyyy]) :
                    "Toque nos pontos para + info",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              )
            )
          ]),
        ),
      ),
    );
  }
}

class ChartButtonWidget extends StatelessWidget {
  final Function changeChart;
  final String chartIndex;
  final String chartName;
  final double btnSize;
  
  ChartButtonWidget({ this.changeChart, this.chartIndex, this.chartName, this.btnSize });

  Widget build(BuildContext context) {
    return Container(
      width: btnSize,
      child: FlatButton(
        color: chartName == chartIndex ? Colors.blue : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.black45),
          borderRadius: BorderRadius.all(Radius.circular(3))),
          child: Text(chartName, style: TextStyle(color: chartName == chartIndex ? Colors.white : Colors.grey)),
            onPressed: () {
              this.changeChart(chartName);
            }
          ),
    );
  }
}
