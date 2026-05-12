#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require "json"
require "yaml"

CLIENT_ROOT = File.expand_path("../../billte-ebics-client", __dir__)
JAVA = File.read(
  File.join(CLIENT_ROOT, "src/main/java/ch/billte/ebics/api/EbicsV3CamtOpenApiExamples.java"),
  encoding: "UTF-8"
)

def extract_java_string_literal(const_name)
  re = /public static final String #{Regexp.escape(const_name)} = "/m
  m = JAVA.match(re)
  raise "missing #{const_name}" unless m

  i = m.end(0)
  buf = +""
  while i < JAVA.length
    c = JAVA[i]
    if c == "\\" && i + 1 < JAVA.length
      buf << c << JAVA[i + 1]
      i += 2
      next
    end
    break if c == '"'

    buf << c
    i += 1
  end
  buf.gsub(/\\u([0-9a-fA-F]{4})/i) { [::Regexp.last_match(1).to_i(16)].pack("U*") }
     .gsub("\\\\", "\u0000ESC\u0000")
     .gsub('\\"', '"')
     .gsub("\\n", "\n")
     .gsub("\\r", "\r")
     .gsub("\\t", "\t")
     .gsub("\u0000ESC\u0000", "\\")
end

def example_json(const_name)
  JSON.parse(extract_java_string_literal(const_name))
end

EX = {
  "c52_canonical_04" => example_json("C52_CANONICAL_RICH_052_001_04_EXAMPLE"),
  "c52_canonical_08" => example_json("C52_CANONICAL_RICH_052_001_08_EXAMPLE"),
  "c52_iso_04" => example_json("C52_ISO_RICH_052_001_04_EXAMPLE"),
  "c52_iso_08" => example_json("C52_ISO_RICH_052_001_08_EXAMPLE"),
  "c53_canonical_04" => example_json("C53_CANONICAL_RICH_053_001_04_EXAMPLE"),
  "c53_canonical_08" => example_json("C53_CANONICAL_RICH_053_001_08_EXAMPLE"),
  "c53_iso_04" => example_json("C53_ISO_RICH_053_001_04_EXAMPLE"),
  "c53_iso_08" => example_json("C53_ISO_RICH_053_001_08_EXAMPLE"),
  "c54_canonical_04" => example_json("C54_CANONICAL_RICH_054_001_04_EXAMPLE"),
  "c54_canonical_08" => example_json("C54_CANONICAL_RICH_054_001_08_EXAMPLE"),
  "c54_iso_04" => example_json("C54_ISO_RICH_054_001_04_EXAMPLE"),
  "c54_iso_08" => example_json("C54_ISO_RICH_054_001_08_EXAMPLE")
}.freeze

REQ_ACTUAL = {}.freeze

def clone_json(obj)
  JSON.parse(JSON.generate(obj))
end

REQ_HIST_C52 = {
  "startDate" => "2026-04-20",
  "endDate" => "2026-04-20"
}.freeze

REQ_HIST_C53_C54 = {
  "startDate" => "2026-04-01",
  "endDate" => "2026-04-20"
}.freeze

MAIN_OPENAPI = "ebics-biller-api.yml"

def standard_errors(canonical:)
  schema_ref = canonical ? "#/components/schemas/CamtCanonicalParseResponse" : "#/components/schemas/CamtIsoParseResponse"
  err_ref = "#{MAIN_OPENAPI}#/components/schemas/ErrorResponse"
  {
    "401" => {
      "description" => <<~TXT.strip,
        Unauthorized. Returned when:
        - the JWT is missing, invalid, or lacks the `EBICS` scope, or
        - the biller's `ebicsStatus` is no longer `ACTIVE` after the token was issued.
      TXT
      "content" => {
        "application/json" => {
          "schema" => { "$ref" => err_ref },
          "examples" => {
            "missingEbicsScope" => {
              "summary" => "JWT is missing the EBICS scope",
              "value" => { "error" => "Unauthorized: missing EBICS scope" }
            },
            "ebicsStatusInactive" => {
              "summary" => "Biller is no longer EBICS-active",
              "description" => "Returned when `ebicsStatus` flips off after the JWT was issued.",
              "value" => { "error" => "Unauthorized: billerPid is not valid or biller is not active" }
            }
          }
        }
      }
    },
    "500" => {
      "description" => "Unexpected server error or BTD error payload (`status` = `ERROR`).",
      "content" => {
        "application/json" => {
          "schema" => { "$ref" => schema_ref }
        }
      }
    }
  }
end

def camt_post(path, operation_id, summary, description, iso, examples_200)
  schema_ref = iso ? "#/components/schemas/CamtIsoParseResponse" : "#/components/schemas/CamtCanonicalParseResponse"
  hist = path.include?("C52") ? REQ_HIST_C52 : REQ_HIST_C53_C54

  body_desc =
    if path.include?("C52")
      "Minimal payloads omit serviceName, scope, msgName, msgNameVersion, containerType — defaults apply (STM, CH, camt.052, 08, ZIP). " \
        "Actual vs historical download follows the same rule as BTD: without dates = actual; with startDate/endDate = historical."
    elsif path.include?("C53")
      "Minimal payloads omit serviceName, scope, msgName, msgNameVersion, containerType — defaults apply (EOP, CH, camt.053, 08, ZIP). " \
        "Actual vs historical download follows the same rule as BTD: without dates = actual; with startDate/endDate = historical."
    else
      "Minimal payloads omit serviceName, scope, msgName, msgNameVersion, containerType — defaults apply (REP, CH, camt.054, 08, ZIP). " \
        "Actual vs historical download follows the same rule as BTD: without dates = actual; with startDate/endDate = historical."
    end

  ex_hist =
    if path.include?("C52")
      { summary: "Intraday account report request (Historical)", desc: "Camt052 v08 Statement (Historical Download for given date range)" }
    elsif path.include?("C53")
      { summary: "Daily account statement request (Historical)", desc: "Camt053 v08 Statement (Historical Download for given date range)" }
    else
      { summary: "Credit/Debit Notifications request (Historical)", desc: "Camt054 v08 Credit/Debit Notifications (Historical Download for given date range)" }
    end

  ex_act =
    if path.include?("C52")
      { summary: "Intraday account report request (Actual)", desc: "Camt052 v08 Statement (Actual download of not-yet downloaded files from bank.)" }
    elsif path.include?("C53")
      { summary: "Daily account statement request (Actual)", desc: "Camt053 v08 Statement (Actual download of not-yet downloaded files from bank.)" }
    else
      { summary: "Credit/Debit Notifications request (Actual)", desc: "Camt054 v08 Credit/Debit Notifications (Actual download of not-yet downloaded files from bank.)" }
    end

  {
    "post" => {
      "summary" => summary,
      "description" => description,
      "operationId" => operation_id,
      "tags" => ["EBICS v3"],
      "requestBody" => {
        "required" => true,
        "description" => body_desc,
        "content" => {
          "application/json" => {
            "schema" => { "$ref" => "#/components/schemas/CamtBtdDerivedParseRequest" },
            "examples" => {
              "actualMinimal" => {
                "summary" => ex_act[:summary],
                "description" => ex_act[:desc],
                "value" => clone_json(REQ_ACTUAL)
              },
              "historicalMinimal" => {
                "summary" => ex_hist[:summary],
                "description" => ex_hist[:desc],
                "value" => clone_json(hist)
              }
            }
          }
        }
      },
      "responses" => {
        "200" => {
          "description" => "Parsed successfully or BTD returned with error payload",
          "content" => {
            "application/json" => {
              "schema" => { "$ref" => schema_ref },
              "examples" => examples_200
            }
          }
        }
      }.merge(standard_errors(canonical: !iso))
    }
  }
end

schemas = {
  "CamtBtdDerivedParseRequest" => {
    "type" => "object",
    "description" => <<~MD.strip,
      Request body for CAMT C52/C53/C54 **ISO** or **canonical** parse operations (mirrors EBICS client `BaseBTDRequest` / `C52Request` / `C53Request` / `C54Request`).

      **Defaults when omitted** depend on the order type (see each path):
      - **C52**: `serviceName` STM, `scope` CH, `msgName` camt.052, `msgNameVersion` 08, `containerType` ZIP
      - **C53**: `serviceName` EOP, `scope` CH, `msgName` camt.053, `msgNameVersion` 08, `containerType` ZIP
      - **C54**: `serviceName` REP, `scope` CH, `msgName` camt.054, `msgNameVersion` 08, `containerType` ZIP

      **Actual vs historical**: same rule as BTD — omit both dates for *actual* (not-yet-downloaded) data; send `startDate` and `endDate` together for a historical window (`yyyy-MM-dd`).
    MD
    "properties" => {
      "requestId" => { "type" => "string", "nullable" => true, "description" => "Optional correlation id; often set server-side." },
      "startDate" => { "type" => "string", "format" => "date", "nullable" => true, "description" => "Historical range start (inclusive)." },
      "endDate" => { "type" => "string", "format" => "date", "nullable" => true, "description" => "Historical range end (inclusive)." },
      "serviceName" => { "type" => "string", "nullable" => true, "description" => "BTF service name (defaults per order type if omitted)." },
      "scope" => { "type" => "string", "nullable" => true, "description" => "BTF scope (default CH)." },
      "msgName" => { "type" => "string", "nullable" => true, "description" => "ISO message name (default camt.052 / .053 / .054 per path)." },
      "msgNameVersion" => { "type" => "string", "nullable" => true, "description" => "Message version (default 08)." },
      "msgNameFormat" => { "type" => "string", "nullable" => true, "description" => "Message format (default XML in client)." },
      "containerType" => { "type" => "string", "nullable" => true, "description" => "Container type (default ZIP)." }
    }
  },
  "CamtCanonicalParseResponse" => {
    "type" => "object",
    "description" => <<~MD.strip,
      Parsed CAMT response in **compact canonical** JSON: BTD-style metadata (`status`, `message`, EBICS return codes when present) plus `parseResult` with `documents` (balances, entries, transactions — field set varies slightly by CAMT flavour).

      On failure the service may return HTTP **500** with `status` = `ERROR` and `message` populated.
    MD
    "additionalProperties" => true,
    "properties" => {
      "ebicsUserId" => { "type" => "string", "nullable" => true },
      "orderType" => { "type" => "string", "example" => "C52" },
      "status" => { "type" => "string" },
      "message" => { "type" => "string", "nullable" => true },
      "dataAvailabilityStatus" => { "type" => "string", "nullable" => true },
      "headerReturnCode" => { "type" => "string", "nullable" => true },
      "headerReturnText" => { "type" => "string", "nullable" => true },
      "bodyReturnCode" => { "type" => "string", "nullable" => true },
      "bodyReturnText" => { "type" => "string", "nullable" => true },
      "bodyReturnSymbolicName" => { "type" => "string", "nullable" => true },
      "parseResult" => { "type" => "object", "additionalProperties" => true, "description" => "Canonical documents and nested entries." }
    }
  },
  "CamtIsoParseResponse" => {
    "type" => "object",
    "description" => <<~MD.strip,
      Parsed CAMT response in **ISO element–aligned** JSON: metadata as for canonical responses, plus a `files` array mirroring ZIP entries. Each file has `zipEntryName`, `schemaNamespace`, and a `Document` object whose root follows the XSD (`BkToCstmrAcctRpt` for CAMT.052, `BkToCstmrStmt` for .053, `BkToCstmrDbtCdtNtfctn` for .054).

      **CAMT.054** adds notification-specific structures (`Ntfctn`, `NtfctnPgntn`, etc.).
    MD
    "additionalProperties" => true,
    "properties" => {
      "ebicsUserId" => { "type" => "string", "nullable" => true },
      "orderType" => { "type" => "string", "example" => "C52" },
      "status" => { "type" => "string" },
      "message" => { "type" => "string", "nullable" => true },
      "dataAvailabilityStatus" => { "type" => "string", "nullable" => true },
      "headerReturnCode" => { "type" => "string", "nullable" => true },
      "headerReturnText" => { "type" => "string", "nullable" => true },
      "bodyReturnCode" => { "type" => "string", "nullable" => true },
      "bodyReturnText" => { "type" => "string", "nullable" => true },
      "bodyReturnSymbolicName" => { "type" => "string", "nullable" => true },
      "files" => { "type" => "array", "items" => { "type" => "object", "additionalProperties" => true }, "description" => "One element per parsed XML inside the BTD ZIP." }
    }
  }
}

# Path order matches `ebics-biller-api.yml` $refs (canonical C52/C53/C54, then ISO).
paths = {
  "/client/ebics/v3/C52-canonical" => camt_post(
    "/client/ebics/v3/C52-canonical",
    "v3C52Canonical",
    "C52 canonical parse (CAMT.052)",
    <<~MD.strip,
      Downloads CAMT.052 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns compact canonical documents, balances, entries, and transactions.

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C52-canonical`.
    MD
    false,
    {
      "camt052Canonical00104" => {
        "summary" => "CAMT.052.001.04 — canonical JSON",
        "description" => "This is example of mapping a camt.052.001.04 to canonical JSON",
        "value" => EX["c52_canonical_04"]
      },
      "camt052Canonical00108" => {
        "summary" => "CAMT.052.001.08 — canonical JSON",
        "description" => "This is example of mapping a camt.052.001.08 to canonical JSON",
        "value" => EX["c52_canonical_08"]
      }
    }
  ),
  "/client/ebics/v3/C53-canonical" => camt_post(
    "/client/ebics/v3/C53-canonical",
    "v3C53Canonical",
    "C53 canonical parse (CAMT.053)",
    <<~MD.strip,
      Downloads CAMT.053 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns compact canonical documents, balances, entries, and transactions.

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C53-canonical`.
    MD
    false,
    {
      "camt053Canonical00104" => {
        "summary" => "CAMT.053.001.04 — canonical JSON",
        "description" => "This is example of mapping a camt.053.001.04 to canonical JSON",
        "value" => EX["c53_canonical_04"]
      },
      "camt053Canonical00108" => {
        "summary" => "CAMT.053.001.08 — canonical JSON",
        "description" => "This is example of mapping a camt.053.001.08 to canonical JSON",
        "value" => EX["c53_canonical_08"]
      }
    }
  ),
  "/client/ebics/v3/C54-canonical" => camt_post(
    "/client/ebics/v3/C54-canonical",
    "v3C54Canonical",
    "C54 canonical parse (CAMT.054)",
    <<~MD.strip,
      Downloads CAMT.054 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns compact canonical documents and entries.
      Compared to C52/C53, CAMT.054 adds notification-specific fields: `relatedAccount` (`RltdAcct`),
      `copyDuplicateIndicator`, `reportingSource`, `transactionsSummary` (`TxsSummry`), and omits statement-style `balances`
      when not present in the message. Each BTD XML notification maps to one element in `parseResult.documents`.

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C54-canonical`.
    MD
    false,
    {
      "camt054Canonical00104" => {
        "summary" => "CAMT.054.001.04 — canonical JSON",
        "description" => "This is example of mapping a camt.054.001.04 to canonical JSON",
        "value" => EX["c54_canonical_04"]
      },
      "camt054Canonical00108" => {
        "summary" => "CAMT.054.001.08 — canonical JSON",
        "description" => "This is example of mapping a camt.054.001.08 to canonical JSON",
        "value" => EX["c54_canonical_08"]
      }
    }
  ),
  "/client/ebics/v3/C52-iso" => camt_post(
    "/client/ebics/v3/C52-iso",
    "v3C52Iso",
    "C52 ISO-structured parse (CAMT.052)",
    <<~MD.strip,
      Downloads CAMT.052 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns ISO element–aligned JSON (camt.052.001.04 / .08).

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C52-iso`.
    MD
    true,
    {
      "camt052Iso00104" => {
        "summary" => "CAMT.052.001.04 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.052.001.04 to ISO-shaped JSON",
        "value" => EX["c52_iso_04"]
      },
      "camt052Iso00108" => {
        "summary" => "CAMT.052.001.08 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.052.001.08 to ISO-shaped JSON",
        "value" => EX["c52_iso_08"]
      }
    }
  ),
  "/client/ebics/v3/C53-iso" => camt_post(
    "/client/ebics/v3/C53-iso",
    "v3C53Iso",
    "C53 ISO-structured parse (CAMT.053)",
    <<~MD.strip,
      Downloads CAMT.053 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns ISO element–aligned JSON (camt.053.001.04 / .08).

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C53-iso`.
    MD
    true,
    {
      "camt053Iso00104" => {
        "summary" => "CAMT.053.001.04 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.053.001.04 to ISO-shaped JSON",
        "value" => EX["c53_iso_04"]
      },
      "camt053Iso00108" => {
        "summary" => "CAMT.053.001.08 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.053.001.08 to ISO-shaped JSON",
        "value" => EX["c53_iso_08"]
      }
    }
  ),
  "/client/ebics/v3/C54-iso" => camt_post(
    "/client/ebics/v3/C54-iso",
    "v3C54Iso",
    "C54 ISO-structured parse (CAMT.054)",
    <<~MD.strip,
      Downloads CAMT.054 via BTD keeping the file local (no cloud upload), parses ZIP/XML with JAXB,
      and returns ISO element–aligned JSON (camt.054.001.04 / .08).
      The `files` array mirrors ZIP entries: each item has `zipEntryName`, `schemaNamespace`, and a `Document` object
      with `BkToCstmrDbtCdtNtfctn` (group header, `Ntfctn` notifications, entries `Ntry`, related account `RltdAcct`,
      `TxsSummry`, etc.). CAMT.054 is a debit/credit notification; pagination uses `NtfctnPgntn`.

      Source: Billte EBICS client `EbicsV3Controller` — `POST /api/ebics/v3/C54-iso`.
    MD
    true,
    {
      "camt054Iso00104" => {
        "summary" => "CAMT.054.001.04 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.054.001.04 to ISO-shaped JSON",
        "value" => EX["c54_iso_04"]
      },
      "camt054Iso00108" => {
        "summary" => "CAMT.054.001.08 — ISO-shaped JSON",
        "description" => "This is example of mapping a camt.054.001.08 to ISO-shaped JSON",
        "value" => EX["c54_iso_08"]
      }
    }
  )
}

def path_item_json_pointer(path)
  "#/paths/" + path.gsub("~", "~0").gsub("/", "~1")
end

out = File.expand_path("../ebics-biller-camt-api.yaml", __dir__)
doc = {
  "openapi" => "3.0.3",
  "info" => {
    "title" => "EBICS Biller API — CAMT parse (fragment)",
    "version" => "1.0.0",
    "description" => <<~MD.strip
      **Fragment** merged into the main EBICS Biller OpenAPI via `$ref` from `#{MAIN_OPENAPI}`.

      Contains CAMT **C52 / C53 / C54** `*-iso` and `*-canonical` path definitions and their schemas (`CamtBtdDerivedParseRequest`, `CamtCanonicalParseResponse`, `CamtIsoParseResponse`).

      `ErrorResponse` for HTTP 401 is referenced from `#{MAIN_OPENAPI}`.

      Regenerate from Java examples: `RUBYOPT='-EUTF-8:UTF-8' ruby scripts/gen_camt_parse_openapi.rb` (run from repo root `ebill-swp-redoc/`).
    MD
  },
  "paths" => paths,
  "components" => {
    "schemas" => schemas
  }
}
yaml = YAML.dump(doc)
yaml.gsub!(/("\$ref"): (ebics-biller-api\.yml#\S+)/, '\1: "\2"')
File.write(out, yaml)
puts "OK #{out}"
puts "Path item pointers (for main spec $ref):"
paths.each_key do |p|
  puts "  #{p} -> ./#{File.basename(out)}#{path_item_json_pointer(p)}"
end
