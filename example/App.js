import React, {useRef} from 'react';
import {Button, Platform, SafeAreaView, View} from 'react-native';
import {DocumentView, Config} from 'react-native-pdftron';

// start util for extracting link stamp data from xfdfCommand
import xml2js from 'react-native-xml2js';

const getData = async xfdfCommand => {
  let data = null;
  await xml2js.parseString(
    xfdfCommand,
    {explicitArray: false},
    (err, result) => {
      if (err) {
        return;
      }
      data = result.xfdf?.annots?.stamp?.['trn-custom-data']?.$?.bytes || null;
    },
  );
  return data;
};
// end util for extracting link stamp data from xfdfCommand

const linkStamps = {
  task: 'https://bina-prod-storage.obs.my-kualalumpur-1.alphaedge.tmone.com.my/Custom-Stamping/Drawings_Stamp%28100px%29/Task%20annotation%20final%20-%20pdftron%20150px%20X%20150px.png',
  drawing:
    'https://bina-prod-storage.obs.my-kualalumpur-1.alphaedge.tmone.com.my/Custom-Stamping/Drawings_Stamp%28100px%29/Drawing%20annotation%20V2%20-%20pdftron%20150px%20150px.png',
  photos:
    'https://bina-prod-storage.obs.my-kualalumpur-1.alphaedge.tmone.com.my/Custom-Stamping/Drawings_Stamp%28100px%29/Camera%20Annotation%20-%20Pdftron%20150px%20x%20150px.png',
  docs: 'https://bina-prod-storage.obs.my-kualalumpur-1.alphaedge.tmone.com.my/Custom-Stamping/Drawings_Stamp%28100px%29/document%20annotation%20-%20pdftron%20150px%20X%20150px.png',
};

const App = () => {
  const _viewer = useRef();

  const onAnnotationActions = ({action, annotations}) => {
    if (_viewer.current) {
      _viewer.current
        .exportAnnotations({annotList: annotations})
        .then(async xfdf => {
          if (action !== 'delete' && typeof action !== 'undefined') {
            console.log('========');
            console.log('Annotation Action: ', action);
            console.log('Annotation ID: ', annotations[0].id);
            console.log(
              'Annotation Type: ',
              JSON.parse((await getData(xfdf)) || '{}')?.data,
            );
            console.log('========');
          }
        });
    }
  };

  const path =
    'https://pdftron.s3.amazonaws.com/downloads/pl/PDFTRON_about.pdf';

  return (
    <SafeAreaView
      style={{
        flex: 1,
        justifyContent: 'center',
      }}>
      <DocumentView
        ref={_viewer}
        hideAnnotationToolbarSwitcher={false}
        hideTopToolbars={false}
        hideTopAppNavBar={false}
        document={path}
        padStatusBar={true}
        showLeadingNavButton={true}
        leadingNavButtonIcon={
          Platform.OS === 'ios'
            ? 'ic_close_black_24px.png'
            : 'ic_arrow_back_white_24dp'
        }
        onAnnotationsSelected={onAnnotationActions}
        onAnnotationChanged={onAnnotationActions}
        readOnly={false}
        disabledElements={[Config.Buttons.userBookmarkListButton]}
        disabledTools={[
          Config.Tools.annotationCreateLine,
          Config.Tools.annotationCreateRectangle,
        ]}
        fitMode={Config.FitMode.FitPage}
        layoutMode={Config.LayoutMode.Continuous}
      />
      <View style={{flexDirection: 'row'}}>
        {Object.keys(linkStamps).map(key => {
          return (
            <View style={{flex: 1, backgroundColor: '#2196F3'}} key={key}>
              <Button
                title={key}
                color={Platform.OS === 'ios' ? '#fff' : '#2196F3'}
                onPress={() => {
                  if (_viewer.current) {
                    _viewer.current.setCustomRubberStampTool(
                      linkStamps[key],
                      key,
                    );
                  }
                }}
              />
            </View>
          );
        })}
      </View>
    </SafeAreaView>
  );
};

export default App;
