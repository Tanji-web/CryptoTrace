import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/trace_models.dart';

void main() {
  group('TraceResult parsing', () {
    test('parses case, nodes, edges, path hops, scores and patterns', () {
      final json = <String, dynamic>{
        'case': {
          'case_id': 'CT-TEST-001',
          'created_at': '2026-09-28T10:00:00Z',
          'schema_version': '1.0',
        },
        'nodes': [
          {
            'id': '0x1111111111111111111111111111111111111111',
            'label': 'Wallet',
            'is_vasp': false,
            'is_target': true,
          },
          {
            'id': '0x2222222222222222222222222222222222222222',
            'label': 'VASP',
            'is_vasp': true,
            'vasp_verified': false,
            'vasp_name': 'Demo Exchange',
            'vasp_type': 'Exchange',
            'is_target': false,
          },
        ],
        'edges': [
          {
            'from': '0x1111111111111111111111111111111111111111',
            'to': '0x2222222222222222222222222222222222222222',
            'asset_type': 'erc20',
            'asset_symbol': 'USDC',
            'amount': 25,
            'tx_hash': '0xabc',
            'timestamp': '2026-09-28T10:00:00Z',
            'block_number': 123,
            'transaction_type': 'token_transfer',
            'token_contract': '0xtoken',
            'token_decimals': 6,
            'token_raw_amount': '25000000',
            'explorer_url': null,
          },
        ],
        'summary': {
          'target_wallet': '0x1111111111111111111111111111111111111111',
          'nearest_vasp': 'Demo Exchange',
          'vasp_type': 'Exchange',
          'vasp_direction': 'outbound',
          'path': [
            '0x1111111111111111111111111111111111111111',
            '0x2222222222222222222222222222222222222222',
          ],
          'path_hops': [
            {
              'from': '0x1111111111111111111111111111111111111111',
              'to': '0x2222222222222222222222222222222222222222',
              'direction': 'outbound',
              'outgoing_tx_hashes': ['0xabc', '0xabc'],
              'incoming_tx_hashes': [],
            },
          ],
          'confidence_score': 80,
          'risk_score': 20,
          'data_source': 'live',
          'scoring_notes': [],
          'confidence_breakdown': {
            'score_type': 'confidence',
            'base_score': 90,
            'factors': [
              {
                'key': 'hop_distance',
                'label': 'Hop distance',
                'points': -10,
                'explanation': 'Test factor',
              },
            ],
            'final_score': 80,
          },
          'risk_breakdown': {
            'score_type': 'risk',
            'base_score': 20,
            'factors': [],
            'final_score': 20,
          },
          'disclaimer': 'Heuristic only.',
          'requested_hops': 2,
          'reached_hops': 1,
        },
        'analysis': {
          'minimum_transfer_eth': 0.0005,
          'transactions_examined': 1,
          'transactions_included': 1,
          'transactions_filtered': 0,
          'filtered_below_eth_threshold': 0,
          'unpriced_token_transactions': 1,
          'filtered_candidate_limit': 0,
          'filtered_non_economic_contract_calls': 0,
          'filtered_other': 0,
          'contract_interactions': 0,
          'internal_eth_transactions': 0,
          'erc20_transactions': 1,
          'limits': {},
          'truncated': false,
          'partial_data': false,
          'api_warnings': [],
        },
        'patterns': [
          {
            'key': 'fan_out',
            'label': 'Fan-out',
            'severity': 'attention',
            'description': 'Test indicator',
            'node_ids': ['0x1111111111111111111111111111111111111111'],
            'tx_hashes': ['0xabc'],
            'evidence': {'counterparty_count': 3},
          },
        ],
      };

      final result = TraceResult.fromJson(json);

      expect(result.caseMetadata.caseId, 'CT-TEST-001');
      expect(result.nodes, hasLength(2));
      expect(result.nodes.last.vaspVerified, isFalse);
      expect(result.edges.single.assetType, 'erc20');
      expect(result.edges.single.tokenDecimals, 6);
      expect(result.edges.single.explorerUrl, isNull);
      expect(result.summary.vaspDirection, 'outbound');
      expect(result.summary.pathHops, hasLength(1));
      expect(result.summary.pathHops.single.transactionHashes, ['0xabc']);
      expect(result.summary.confidenceBreakdown?.finalScore, 80);
      expect(result.summary.riskBreakdown?.finalScore, 20);
      expect(result.patterns.single.key, 'fan_out');
    });
  });

  group('PathHop', () {
    test('deduplicates transaction hashes across directions', () {
      const hop = PathHop(
        from: 'A',
        to: 'B',
        direction: 'mixed',
        outgoingTxHashes: ['tx1', 'tx2'],
        incomingTxHashes: ['tx2', 'tx3'],
      );

      expect(hop.transactionHashes, containsAll(<String>['tx1', 'tx2', 'tx3']));
      expect(hop.transactionHashes, hasLength(3));
    });
  });
}
