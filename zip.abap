
REPORT zprocess_zip.

DATA: lv_zip_content       TYPE xstring,
      lv_boundary          TYPE string,
      lt_zip_entries       TYPE TABLE OF string,
      lt_file_content      TYPE TABLE OF xstring,
      lv_index_html        TYPE string,
      lv_main_html_name    TYPE string,
      lv_authorization     TYPE string,
      lv_output_file_name  TYPE string,
      lt_multipart_body    TYPE TABLE OF xstring.

CONSTANTS: lc_boundary_prefix TYPE string VALUE '--------------------------'.

* Read ZIP content (e.g., from an input field or table)
lv_zip_content = cl_abap_conv_in_ce=>create(
                 )->read_xstring(
                     EXPORTING input = lv_raw_zip_data ).

* Process ZIP file
TRY.
    DATA(lo_zip) = NEW cl_abap_zip( iv_input = lv_zip_content ).
    DATA(lt_files) = lo_zip->get_entries( ).

    LOOP AT lt_files INTO DATA(ls_file).
      DATA(lv_file_name) = ls_file-name.
      DATA(lv_file_content) = lo_zip->get_data( iv_name = lv_file_name ).

      IF lv_file_name CP '*.html'.
        lv_index_html = cl_abap_conv_in_ce=>create(
                          )->read_string(
                              EXPORTING input = lv_file_content ).
        lv_main_html_name = lv_file_name.
      ELSE.
        APPEND lv_file_content TO lt_file_content.
      ENDIF.
    ENDLOOP.
  CATCH cx_abap_zip.
    WRITE: / 'Error processing ZIP file.'.
    RETURN.
ENDTRY.

* Ensure HTML file is found
IF lv_index_html IS INITIAL.
  WRITE: / 'No HTML file found in ZIP.'.
  RETURN.
ENDIF.

* Prepare multipart/form-data
lv_boundary = lc_boundary_prefix && sy-datum && sy-uzeit.

APPEND |--{ lv_boundary } CRLF
Content-Disposition: form-data; name="file"; filename="{ lv_main_html_name }"
Content-Type: text/html
CRLF CRLF{ lv_index_html }CRLF
| TO lt_multipart_body.

LOOP AT lt_file_content INTO DATA(lv_other_file).
  APPEND |--{ lv_boundary } CRLF
Content-Disposition: form-data; name="file"; filename="{ lv_file_name }"
Content-Type: application/octet-stream
CRLF CRLF{ lv_other_file }CRLF
| TO lt_multipart_body.
ENDLOOP.

APPEND |--{ lv_boundary }--CRLF| TO lt_multipart_body.

* Set HTTP request
DATA(lo_http_client) = cl_http_client=>create_by_url(
                         EXPORTING url = 'https://api.pdfcrowd.com/' ).

DATA(lv_auth) = cl_abap_base64=>encode( EXPORTING iv_raw = 'Ariadna129:f7345fa63dc68480d9145ce871cb51bf' ).

lo_http_client->request->set_header_field( name = 'Authorization' value = |Basic { lv_auth }| ).
lo_http_client->request->set_header_field( name = 'Content-Type' value = |multipart/form-data; boundary={ lv_boundary }| ).
lo_http_client->request->set_cdata( lv_multipart_body ).

* Send HTTP request
TRY.
    lo_http_client->send( ).
    lo_http_client->receive( ).
    WRITE: / lo_http_client->response->get_status( ).
    WRITE: / lo_http_client->response->get_cdata( ).
  CATCH cx_http_client.
    WRITE: / 'HTTP Error occurred.'.
ENDTRY.
