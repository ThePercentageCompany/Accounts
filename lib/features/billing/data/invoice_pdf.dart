import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/models.dart';
import '../domain/invoice_document_service.dart';
import '../domain/totals.dart';

class PdfInvoiceDocumentService implements InvoiceDocumentService {
@override
Future<Uint8List> render(Invoice i, {Payment? receipt}) async {
  final doc=pw.Document();
  final t=Totals.of(i), c=i.company;
  pw.Widget text(String v,{bool bold=false,double size=10})=>pw.Text(v,style:pw.TextStyle(fontSize:size,fontWeight:bold?pw.FontWeight.bold:pw.FontWeight.normal));
  pw.Widget summary(String label,int value,{bool bold=false})=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:5),child:pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[text(label,bold:bold),text(money(value),bold:bold)]));
  final logo=c.logo.isEmpty?null:pw.MemoryImage(base64Decode(c.logo));
  doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(38),
    footer:(context)=>pw.Column(children:[pw.Divider(color:PdfColors.grey400),pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[text(c.name,size:8),text('${context.pageNumber} / ${context.pagesCount}',size:8)])]),
    build:(context)=>[
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
        pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
          if(logo!=null) pw.Padding(padding:const pw.EdgeInsets.only(bottom:12),child:pw.Image(logo,width:110,height:52,fit:pw.BoxFit.contain)),
          text(c.name,bold:true,size:12),pw.SizedBox(height:4),text(c.address),text(c.phone),text(c.email),if(c.trn.isNotEmpty) text('TRN: ${c.trn}'),
        ])),pw.SizedBox(width:25),pw.SizedBox(width:205,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.end,children:[
          text(receipt!=null?'PAYMENT RECEIPT':i.status=='draft'?'DRAFT INVOICE':i.status=='void'?'VOID INVOICE':'INVOICE',size:22),
          pw.SizedBox(height:12),text(i.number.isEmpty?'Draft - no invoice number':i.number,size:12),pw.SizedBox(height:10),
          text(receipt!=null?'Payment received':'Balance Due',bold:true),text(money(receipt?.cents??t.balance),bold:true,size:15),
        ])),
      ]),
      pw.SizedBox(height:36),
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
        text('Bill To'),pw.SizedBox(height:4),text(i.customer.name,bold:true),text(i.customer.address),if(i.customer.email.isNotEmpty) text(i.customer.email),if(i.customer.phone.isNotEmpty) text(i.customer.phone),if(i.customer.trn.isNotEmpty) text('TRN: ${i.customer.trn}'),
      ])),pw.SizedBox(width:20),pw.SizedBox(width:205,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.end,children:[text('Invoice Date: ${i.date}'),pw.SizedBox(height:6),text('Terms: ${i.terms}'),if(i.dueDate.isNotEmpty) text('Due Date: ${i.dueDate}')]))]),
      pw.SizedBox(height:26),
      if(receipt==null) pw.TableHelper.fromTextArray(
        headers:['#','Item & Description','Qty','Rate','Amount'],
        data:[for(var n=0;n<i.items.length;n++) ['${n+1}',i.items[n].description,i.items[n].quantity,(scaled(i.items[n].rate,2)/100).toStringAsFixed(2),(lineTotal(i.items[n])/100).toStringAsFixed(2)]],
        headerDecoration:const pw.BoxDecoration(color:PdfColors.grey800),headerStyle:pw.TextStyle(color:PdfColors.white,fontSize:9,fontWeight:pw.FontWeight.bold),
        cellStyle:const pw.TextStyle(fontSize:9),cellPadding:const pw.EdgeInsets.all(8),border:const pw.TableBorder(horizontalInside:pw.BorderSide(color:PdfColors.grey400,width:0.5)),
        columnWidths:{0:const pw.FlexColumnWidth(.4),1:const pw.FlexColumnWidth(4),2:const pw.FlexColumnWidth(.7),3:const pw.FlexColumnWidth(1.1),4:const pw.FlexColumnWidth(1.2)},
        cellAlignments:{0:pw.Alignment.center,1:pw.Alignment.centerLeft,2:pw.Alignment.centerRight,3:pw.Alignment.centerRight,4:pw.Alignment.centerRight}),
      if(receipt!=null) pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[text('Payment date: ${receipt.date}'),text('Receipt ID: ${receipt.id}'),text('Reference: ${receipt.reference}'),pw.SizedBox(height:15)]),
      pw.Align(alignment:pw.Alignment.centerRight,child:pw.SizedBox(width:260,child:pw.Column(children:[
        summary('Item total',t.subtotal),summary('Discount',t.discount),summary('Subtotal',t.subtotal-t.discount),if(t.tax>0) summary('Tax (${i.taxRate}%)',t.tax),summary('Invoice Total',t.total,bold:true),summary('Amount paid',t.paid),
        pw.Container(padding:const pw.EdgeInsets.symmetric(horizontal:10),color:PdfColors.grey100,child:summary('Balance Due',t.balance,bold:true)),
      ]))),
      pw.SizedBox(height:32),text('Bank Details For Payment',bold:true),pw.SizedBox(height:5),
      text('Account Holder: ${c.accountHolder}'),text('Bank Name: ${c.bank}'),text('Account Number: ${c.accountNumber}'),if(c.iban.isNotEmpty) text('IBAN: ${c.iban}'),
      pw.SizedBox(height:25),text('Notes',bold:true),pw.SizedBox(height:5),text(i.notes),
      if(i.number.startsWith('DEMO-')) pw.Padding(padding:const pw.EdgeInsets.only(top:20),child:text('DEMO - NOT FOR CUSTOMER BILLING',bold:true)),
    ]));
  return doc.save();
}

}
