import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';

class FactureService {
  Future<void> genererEtPartager(Order order) async {
    final pdf = await _genererPdf(order);
    await Printing.sharePdf(
      bytes: pdf,
      filename: 'facture_${order.shortId}',
    );
  }

  Future<Uint8List> _genererPdf(Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          _buildHeader(order),
          pw.SizedBox(height: 24),
          _buildOrderInfo(order),
          pw.SizedBox(height: 24),
          _buildItemsTable(order),
          pw.SizedBox(height: 24),
          _buildTotal(order),
          pw.SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Order order) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SEN-EAU',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.Text('FACTURE',
                style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Distribution d\'eau minérale',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.Divider(color: PdfColors.blue200, thickness: 2),
      ],
    );
  }

  pw.Widget _buildOrderInfo(Order order) {
    final status = order.status;
    final date =
        '${order.createdAt.day.toString().padLeft(2, '0')}/'
        '${order.createdAt.month.toString().padLeft(2, '0')}/'
        '${order.createdAt.year}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('N° commande : #${order.shortId}',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.Text('Date : $date',
                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text('Statut : ${status.label}',
            style: pw.TextStyle(
                color: _pdfColor(status.color),
                fontWeight: pw.FontWeight.bold,
                fontSize: 11)),
        if (order.paymentMethod != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('Paiement : ${order.paymentMethod!.toUpperCase()}',
              style: pw.TextStyle(
                  color: PdfColors.green700,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11)),
        ],
        pw.SizedBox(height: 12),
        pw.Text('Client : ${order.boutiquierId.substring(0, 8)}...',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildItemsTable(Order order) {
    const headers = ['Produit', 'Qté', 'Prix unitaire', 'Total'];
    final rows = order.items.map((item) {
      return [
        item.product?.nom ?? 'Produit',
        '${item.quantity}',
        '${item.priceAtOrder.toStringAsFixed(0)} FCFA',
        '${item.total.toStringAsFixed(0)} FCFA',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: headers,
      data: rows,
    );
  }

  pw.Widget _buildTotal(Order order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('TOTAL À PAYER',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('${order.totalPrice.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20,
                      color: PdfColors.blue800)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Text(
          'sen-eau - Plateforme de distribution d\'eau minérale',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Merci de votre confiance !',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  PdfColor _pdfColor(Color flutterColor) {
    return PdfColor.fromInt(flutterColor.toARGB32());
  }
}
