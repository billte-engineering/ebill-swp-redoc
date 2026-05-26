# frozen_string_literal: true

require 'yaml'
require 'json'

UPLOAD_YAML = File.expand_path('../ebics-biller-upload-api.yaml', __dir__)
JAVA = File.expand_path(
  '../../billte-ebics-client/src/main/java/ch/billte/ebics/api/EbicsV3Pain001OpenApiExamples.java',
  __dir__
)

def extract_json(text, name)
  start = text.index("public static final String #{name} = ")
  raise "missing constant #{name}" unless start

  i = start + "public static final String #{name} = ".length
  parts = []
  while i < text.length
    i += 1 while i < text.length && " \t\n+".include?(text[i])
    break unless text[i] == '"'

    i += 1
    chunk = +''
    while i < text.length
      if text[i] == '\\' && i + 1 < text.length
        chunk << text[i, 2]
        i += 2
        next
      end
      break if text[i] == '"'

      chunk << text[i]
      i += 1
    end
    parts << chunk
    i += 1
  end
  raw = parts.join.encode('utf-8').gsub(/\\n/, "\n").gsub(/\\"/, '"')
  JSON.parse(raw)
end

text = File.read(JAVA)
doc = YAML.load_file(UPLOAD_YAML)

doc['info']['description'] = <<~DESC.strip
  **Fragment** merged into the main EBICS Biller OpenAPI via `$ref` from `ebics-biller-api.yml`.

  Contains the **BTU** (Business Transaction Upload) paths and schemas:
  - `BTURequest` / `BTUResponse` — raw file upload via `/btu`
  - `Pain001BTURequest` / `Pain001BTUResponse` — structured pain.001 payment orders via `/pain001`

  `ErrorResponse` for HTTP 401 is referenced from `ebics-biller-api.yml`.
DESC

doc['paths']['/client/ebics/v3/pain001'] = {
  'post' => {
    'summary' => 'Upload pain.001 payment order',
    'description' => <<~DESC.strip,
      Simplified method to create common pain.001 payment orders.

      Design simplification constraints:

      - One request produces exactly one B-Level (PmtInf) block
      - Batch booking (BtchBookg) is always true
      - Support IBAN account numbers, and BIC identifiers (no proprietary)

      Note: Use `/btu` operation directly in case you need advanced control over generated pain.001 xml, like (multiple PmtInf, proprietary account numbers, forwarding agents,..)

      Identifiers (messageId, instructionId, endToEndId, uetr) are optional. In case they are omited or blank, they will be auto-generated
      The response includes creditTransfer object with the effective ID values used in the generated pain.001.
      The pain.001 schema (pain.001.001.03 or pain.001.001.09) is selected automatically based on
      msgName, msgNameVersion and msgNameVariant:

      | msgName | msgNameVersion | msgNameVariant | Selected schema |
      | --- | --- | --- | --- |
      | pain.001 | `03` | `001` | pain.001.001.03 |
      | pain.001 | `03` | omitted | pain.001.001.03 |
      | pain.001 | `09` | `001` | pain.001.001.09 |
      | pain.001 | `09` | omitted | pain.001.001.09 |
      | pain.001 | omitted | omitted | pain.001.001.09 |
    DESC
    'operationId' => 'v3Pain001',
    'tags' => ['EBICS v3 Upload'],
    'requestBody' => {
      'required' => true,
      'description' => 'pain001 upload request parameters describing BTF (Business Transaction Format) attributes and credit transfer transactions.',
      'content' => {
        'application/json' => {
          'schema' => { '$ref' => '#/components/schemas/Pain001BTURequest' },
          'examples' => {
            'chfDomesticInstant' => {
              'summary' => 'Swiss domestic instant (CHF)',
              'description' => 'Swiss domestic instant credit transfer with two CHF transactions; set localInstrument to INST (Instant payment)',
              'value' => extract_json(text, 'CHF_DOMESTIC_INST_REQUEST')
            },
            'sepaInstant' => {
              'summary' => 'SEPA instant (CH to DE and CZ)',
              'description' => 'SEPA instant payment 2 transactions from CH to DE and CZ; serviceLevel SEPA and localInstrument INST (Instant payment)',
              'value' => extract_json(text, 'SEPA_INST_REQUEST')
            },
            'internationalUsdUae' => {
              'summary' => 'International payment (DE to UAE and Brazil)',
              'description' => 'Standard international credit transfer, 2 transactions from Germany to UAE and Brazil (USD + BRL); omit serviceLevel and localInstrument',
              'value' => extract_json(text, 'INTERNATIONAL_USD_UAE_REQUEST')
            }
          }
        }
      }
    },
    'responses' => {
      '200' => {
        'description' => 'pain.001 BTU executed successfully; creditTransfer contains resolved identifiers',
        'content' => {
          'application/json' => {
            'schema' => { '$ref' => '#/components/schemas/Pain001BTUResponse' },
            'examples' => {
              'successResponse' => {
                'summary' => 'Success Response',
                'description' => 'BTU upload succeeded; response echoes creditTransfer with server-generated messageId and paymentIdentification',
                'value' => extract_json(text, 'SUCCESS_RESPONSE')
              }
            }
          }
        }
      },
      '400' => {
        'description' => 'Invalid request, unsupported pain.001 schema combination, or generated XML failed XSD validation',
        'content' => {
          'application/json' => {
            'schema' => { '$ref' => '#/components/schemas/Pain001ValidationErrorResponse' },
            'examples' => {
              'unsupportedPain001Schema' => {
                'summary' => 'Unsupported pain.001 schema',
                'description' => 'Returned when BTF attributes do not resolve to pain.001.001.03 or pain.001.001.09 (e.g. msgNameVersion 05 with msgNameVariant 001)',
                'value' => extract_json(text, 'UNSUPPORTED_SCHEMA_BAD_REQUEST')
              },
              'pain001XmlSchemaValidationFailed' => {
                'summary' => 'pain.001 XML schema validation failed',
                'description' => 'Returned when marshalled pain.001 XML does not pass ISO 20022 XSD validation; often caused by invalid creditor.agent.bic (example: BBREBRRJAXXX with msgNameVersion 03)',
                'value' => extract_json(text, 'XML_SCHEMA_VALIDATION_BAD_REQUEST')
              }
            }
          }
        }
      },
      '401' => {
        'description' => "Unauthorized. Returned when:\n- the JWT is missing, invalid, or lacks the `EBICS` scope, or\n- the biller's `ebicsStatus` is no longer `ACTIVE` after the token was issued.\n",
        'content' => {
          'application/json' => {
            'schema' => { '$ref' => 'ebics-biller-api.yml#/components/schemas/ErrorResponse' },
            'examples' => {
              'missingEbicsScope' => {
                'summary' => 'JWT is missing the EBICS scope',
                'value' => { 'error' => 'Unauthorized: missing EBICS scope' }
              },
              'ebicsStatusInactive' => {
                'summary' => 'Biller is no longer EBICS-active',
                'description' => 'Returned when `ebicsStatus` flips off after the JWT was issued.',
                'value' => { 'error' => 'Unauthorized: billerPid is not valid or biller is not active' }
              }
            }
          }
        }
      },
      '500' => {
        'description' => 'Internal server error during BTU execution'
      }
    }
  }
}

schemas = doc['components']['schemas']

schemas['Pain001ValidationErrorResponse'] = {
  'type' => 'object',
  'description' => 'Validation error returned for invalid pain.001 BTU requests',
  'properties' => {
    'errorMessage' => { 'type' => 'string', 'description' => 'Human-readable error message' },
    'statusCode' => { 'type' => 'string', 'description' => 'HTTP status phrase', 'example' => 'Bad Request' }
  }
}

schemas['Pain001BTURequest'] = {
  'type' => 'object',
  'description' => 'BTU request for pain.001 (Customer Credit Transfer Initiation) with structured credit transfer data',
  'required' => ['creditTransfer'],
  'properties' => {
    'ebicsUserId' => { 'type' => 'string', 'description' => 'EBICS user identifier used for authentication at the bank', 'example' => 'ZKB03305' },
    'billerId' => { 'type' => 'string', 'description' => 'Internal biller/tenant identifier used by this application', 'example' => 'billte-ch' },
    'fileName' => { 'type' => 'string', 'description' => 'Logical file name for the uploaded payload (e.g. pain XML file name)', 'example' => 'pain.001.001.09-20260501-sepa.xml' },
    'serviceName' => { 'type' => 'string', 'description' => 'BTF service name (e.g. payment or collection service family)', 'example' => 'MCT' },
    'scope' => { 'type' => 'string', 'description' => 'BTF scope value defined by the bank for this service', 'example' => 'CH' },
    'serviceOption' => { 'type' => 'string', 'nullable' => true, 'description' => 'Optional BTF service option if required by the bank' },
    'msgName' => { 'type' => 'string', 'description' => 'Message name of the uploaded format', 'example' => 'pain.001', 'default' => 'pain.001' },
    'msgNameVersion' => { 'type' => 'string', 'description' => 'Message name version', 'example' => '09' },
    'msgNameVariant' => { 'type' => 'string', 'nullable' => true, 'description' => 'Message name variant', 'example' => '001' },
    'msgNameFormat' => { 'type' => 'string', 'nullable' => true, 'description' => 'Message format', 'example' => 'XML' },
    'containerType' => { 'type' => 'string', 'nullable' => true, 'description' => 'Container type for the uploaded data (XML, ZIP, SVC)', 'example' => 'XML' },
    'signatureFlag' => {
      'type' => 'boolean',
      'description' => 'Set to true for EBICS upload Method 1 (default) and false for Method 2 (manual). Maps to BTU SignatureFlag.',
      'example' => true
    },
    'signatureFlagEds' => {
      'type' => 'boolean',
      'description' => 'Set to false for fully signed orders, true for partially signed orders (EDS forwarding). Use only when signatureFlag is true.',
      'example' => false
    },
    'creditTransfer' => { '$ref' => '#/components/schemas/CreditTransfer' }
  }
}

schemas['Pain001BTUResponse'] = {
  'type' => 'object',
  'description' => 'pain.001 BTU response: standard BTU fields plus credit transfer with resolved identifiers',
  'required' => ['creditTransfer'],
  'properties' => {
    'ebicsUserId' => { 'type' => 'string', 'description' => 'EBICS user identifier used for the request', 'example' => 'ZKB03305' },
    'status' => { 'type' => 'string', 'description' => 'High-level processing status of the BTU operation', 'example' => 'SUCCESS' },
    'message' => { 'type' => 'string', 'nullable' => true, 'description' => 'Human-readable message describing the BTU processing result' },
    'transactionId' => { 'type' => 'string', 'nullable' => true, 'description' => 'EBICS transaction identifier returned by the bank' },
    'orderId' => { 'type' => 'string', 'nullable' => true, 'description' => 'EBICS order identifier associated with the BTU request' },
    'receiptCode' => { 'type' => 'string', 'nullable' => true, 'description' => 'Bank receipt code confirming upload handling (currently always null)' },
    'creditTransfer' => { '$ref' => '#/components/schemas/CreditTransfer' }
  }
}

schemas['CreditTransfer'] = {
  'type' => 'object',
  'description' => 'Credit transfer initiation (payment order). pain.001.001.03, pain.001.001.09: CstmrCdtTrfInitn.',
  'required' => %w[initPartyDebtor transactionsInfo transactions],
  'properties' => {
    'messageId' => {
      'type' => 'string',
      'nullable' => true,
      'description' => 'Optional client-provided message identification (GrpHdr/MsgId). If omitted or blank, the server generates MSG-{yyyyMMddHHmmss} (UTC) before upload.',
      'example' => 'MSG-20260521143022',
      'minLength' => 1,
      'maxLength' => 35
    },
    'initPartyDebtor' => { '$ref' => '#/components/schemas/Debtor' },
    'transactionsInfo' => { '$ref' => '#/components/schemas/CreditTransferTransactionsInfo' },
    'transactions' => {
      'type' => 'array',
      'minItems' => 1,
      'items' => { '$ref' => '#/components/schemas/CreditTransferTransaction' }
    }
  }
}

schemas['CreditTransferTransactionsInfo'] = {
  'type' => 'object',
  'description' => 'Batch-level payment instruction data shared by all transactions. pain.001.001.03, pain.001.001.09: PmtInf.',
  'required' => ['executionDate'],
  'properties' => {
    'executionDate' => { 'type' => 'string', 'format' => 'date', 'description' => 'Requested transaction execution date', 'example' => '2027-06-18' },
    'localInstrument' => { 'type' => 'string', 'nullable' => true, 'description' => 'Local instrument code (PmtInf/PmtTpInf/LclInstrm/Cd), e.g. INST for instant payment', 'example' => 'INST' },
    'serviceLevel' => { 'type' => 'string', 'nullable' => true, 'description' => 'Service level code (PmtInf/PmtTpInf/SvcLvl/Cd), e.g. SEPA', 'example' => 'SEPA' },
    'instructionPriority' => { 'type' => 'string', 'nullable' => true, 'description' => 'Instruction priority (PmtInf/PmtTpInf/InstrPrty): HIGH or NORM', 'example' => 'NORM' }
  }
}

schemas['CreditTransferTransaction'] = {
  'type' => 'object',
  'description' => 'Single credit transfer within a payment instruction. pain.001.001.03, pain.001.001.09: PmtInf/CdtTrfTxInf.',
  'required' => %w[amount creditor],
  'properties' => {
    'paymentIdentification' => { '$ref' => '#/components/schemas/PaymentIdentification' },
    'amount' => { '$ref' => '#/components/schemas/Amount' },
    'remittanceInformation' => { '$ref' => '#/components/schemas/RemittanceInformation' },
    'creditor' => { '$ref' => '#/components/schemas/Creditor' }
  }
}

schemas['Debtor'] = {
  'type' => 'object',
  'description' => 'Initiating party and debtor of a credit transfer initiation.',
  'required' => %w[name iban agent],
  'properties' => {
    'name' => { 'type' => 'string', 'description' => 'Name of the initiating party and debtor', 'example' => 'Peter Muster', 'minLength' => 1, 'maxLength' => 70 },
    'iban' => { 'type' => 'string', 'description' => 'IBAN of the debtor account without spaces and dashes', 'example' => 'DE89370400440532013000', 'maxLength' => 30 },
    'agent' => { '$ref' => '#/components/schemas/FinancialInstitutionIdentification' }
  }
}

schemas['Creditor'] = {
  'type' => 'object',
  'description' => 'Creditor of a credit transfer transaction.',
  'required' => %w[name iban],
  'properties' => {
    'name' => { 'type' => 'string', 'description' => 'Name of the creditor party', 'example' => 'Mustermann GmbH', 'minLength' => 1, 'maxLength' => 70 },
    'iban' => { 'type' => 'string', 'description' => 'IBAN of the creditor account without spaces and dashes', 'example' => 'CH4700762001234567890', 'maxLength' => 30 },
    'agent' => { '$ref' => '#/components/schemas/FinancialInstitutionIdentification' }
  }
}

schemas['Amount'] = {
  'type' => 'object',
  'description' => 'Instructed amount of a credit transfer transaction.',
  'required' => %w[currency value],
  'properties' => {
    'currency' => { 'type' => 'string', 'description' => 'ISO 4217 currency code', 'example' => 'CHF' },
    'value' => { 'type' => 'number', 'format' => 'double', 'description' => 'Instructed amount', 'example' => 1200.35 }
  }
}

schemas['PaymentIdentification'] = {
  'type' => 'object',
  'description' => 'Payment identification (PmtInf/CdtTrfTxInf/PmtId).',
  'properties' => {
    'instructionId' => { 'type' => 'string', 'nullable' => true, 'description' => 'Optional instruction id; auto-generated if omitted', 'example' => 'INS-20260521143022-001', 'maxLength' => 35 },
    'endToEndId' => { 'type' => 'string', 'nullable' => true, 'description' => 'Optional end-to-end id; auto-generated if omitted', 'example' => 'E2E-20260521143022-001', 'maxLength' => 35 },
    'uetr' => { 'type' => 'string', 'nullable' => true, 'description' => 'Optional UETR (pain.001.001.09 only); auto-generated UUID v4 if omitted', 'example' => 'a3b2c1d0-e5f4-4789-a012-3456789abcde' }
  }
}

schemas['RemittanceInformation'] = {
  'type' => 'object',
  'description' => 'Remittance information (PmtInf/CdtTrfTxInf/RmtInf).',
  'properties' => {
    'unstructuredRemittanceInformation' => { 'type' => 'string', 'nullable' => true, 'description' => 'Unstructured remittance (RmtInf/Ustrd)', 'maxLength' => 140 },
    'structuredRemittanceInformation' => { '$ref' => '#/components/schemas/StructuredRemittanceInformation' }
  }
}

schemas['StructuredRemittanceInformation'] = {
  'type' => 'object',
  'description' => 'Structured remittance information (RmtInf/Strd).',
  'properties' => {
    'creditorReference' => { '$ref' => '#/components/schemas/CreditorReference' }
  }
}

schemas['CreditorReference'] = {
  'type' => 'object',
  'description' => 'Creditor reference (RmtInf/Strd/CdtrRefInf).',
  'properties' => {
    'code' => { 'type' => 'string', 'description' => 'Creditor reference type code (ISO DocumentType3Code or proprietary, e.g. QRR)', 'example' => 'SCOR' },
    'reference' => { 'type' => 'string', 'description' => 'Creditor reference value', 'example' => 'RF712348231' }
  }
}

schemas['FinancialInstitutionIdentification'] = {
  'type' => 'object',
  'description' => 'Financial institution identification of a payment agent (BIC / BICFI).',
  'required' => ['bic'],
  'properties' => {
    'bic' => { 'type' => 'string', 'description' => 'BIC of the financial institution (ISO 9362)', 'example' => 'RAIFCH22' }
  }
}

yaml = doc.to_yaml(line_width: -1)
yaml = yaml.gsub("receiptCode: \n", "receiptCode: null\n")
File.write(UPLOAD_YAML, "---\n#{yaml.sub(/\A---\n/, '')}")
puts "Updated #{UPLOAD_YAML}"
