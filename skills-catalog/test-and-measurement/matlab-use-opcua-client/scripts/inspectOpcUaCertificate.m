function inspectOpcUaCertificate(certFile)
%inspectOpcUaCertificate Check certificate for OPC UA Part 6 compliance.
%   inspectOpcUaCertificate(certFile) inspects an OPC UA certificate (.der
%   or .pem) and reports PASS/FAIL on Part 6 Section 6.2.2 fields: RSA key
%   length, signature algorithm, key usage, Subject Alternative Name,
%   validity, and Basic Constraints (end-entity).
%
%   Uses openssl when available; falls back to Java's CertificateFactory
%   when openssl is not on PATH.
%
%   Example:
%       inspectOpcUaCertificate("C:/certs/server_cert.der")

    arguments
        certFile (1, 1) string {mustBeFile}
    end

    if hasOpenssl()
        inspectWithOpenssl(certFile);
    elseif hasJava()
        inspectWithJava(certFile);
    else
        error("inspectOpcUaCertificate:NoBackend", ...
            "Neither openssl nor a Java X.509 API is available. " + ...
            "Install openssl and ensure it is on PATH.");
    end
end

function tf = hasOpenssl()
    if ispc
        cmd = "where openssl";
    else
        cmd = "command -v openssl";
    end
    [status, ~] = system(cmd);
    tf = status == 0;
end

function tf = hasJava()
    tf = usejava("jvm");
end

function inspectWithOpenssl(certFile)
    [status, output] = system(sprintf( ...
        'openssl x509 -in "%s" -inform DER -text -noout', certFile));
    if status ~= 0
        error("openssl failed: %s", output);
    end
    text = string(output);

    fprintf("=== OPC UA Certificate Compliance (openssl) ===\n");
    fprintf("File: %s\n", certFile);
    fprintf("%s\n", extractField(text, "Subject:"));
    fprintf("%s\n", extractField(text, "Issuer:"));
    fprintf("Serial: %s\n", strtrim(extractField(text, "Serial Number:")));
    fprintf("Not Before:%s\n", erase(extractField(text, "Not Before:"), "Not Before:"));
    fprintf("Not After :%s\n", erase(extractField(text, "Not After :"), "Not After :"));

    keyBitsTok = regexp(text, "Public-Key:\s*\((\d+)\s*bit\)", "tokens", "once");
    if ~isempty(keyBitsTok)
        keyLen = str2double(keyBitsTok{1});
        fprintf("RSA Key Length: %d bits %s\n", keyLen, ...
            ternary(keyLen >= 2048, "[PASS]", "[FAIL needs >=2048]"));
    end

    sigAlgTok = regexp(text, "Signature Algorithm:\s*(\S+)", "tokens", "once");
    if ~isempty(sigAlgTok)
        sigAlg = string(sigAlgTok{1});
        isSha2Plus = contains(sigAlg, ["sha256", "sha384", "sha512"], ...
            IgnoreCase=true);
        fprintf("Signature: %s %s\n", sigAlg, ...
            ternary(isSha2Plus, "[PASS]", "[FAIL needs SHA-256+]"));
    end

    kuTok = regexp(text, "X509v3 Key Usage:[^\n]*\n\s*([^\n]+)", ...
        "tokens", "once");
    if ~isempty(kuTok)
        kuLine = string(kuTok{1});
        hasDigSig  = contains(kuLine, "Digital Signature");
        hasNonRep  = contains(kuLine, "Non Repudiation");
        hasKeyEnc  = contains(kuLine, "Key Encipherment");
        hasDataEnc = contains(kuLine, "Data Encipherment");
        allPresent = hasDigSig && hasNonRep && hasKeyEnc && hasDataEnc;
        fprintf("Key Usage: DigSig=%d NonRep=%d KeyEnc=%d DataEnc=%d %s\n", ...
            hasDigSig, hasNonRep, hasKeyEnc, hasDataEnc, ...
            ternary(allPresent, "[PASS]", "[FAIL missing required bits]"));
    else
        fprintf("Key Usage: [FAIL extension missing]\n");
    end

    sanTok = regexp(text, ...
        "X509v3 Subject Alternative Name:[^\n]*\n\s*([^\n]+)", ...
        "tokens", "once");
    if ~isempty(sanTok)
        fprintf("Subject Alt Names: [PASS]\n  %s\n", string(sanTok{1}));
    else
        fprintf("Subject Alt Names: [FAIL missing]\n");
    end

    bcTok = regexp(text, ...
        "X509v3 Basic Constraints:[^\n]*\n\s*([^\n]+)", "tokens", "once");
    if ~isempty(bcTok)
        bcLine = string(bcTok{1});
        isCa = contains(bcLine, "CA:TRUE");
        fprintf("Basic Constraints: %s %s\n", strtrim(bcLine), ...
            ternary(~isCa, "[PASS end-entity]", "[FAIL must be end-entity]"));
    end
end

function value = extractField(text, label)
    tok = regexp(text, label + "[^\n]*", "match", "once");
    if isempty(tok)
        value = label + " (not found)";
    else
        value = strtrim(string(tok));
    end
end

function inspectWithJava(certFile)
    fis = java.io.FileInputStream(certFile);
    cleanup = onCleanup(@() fis.close());
    cf = java.security.cert.CertificateFactory.getInstance("X.509");
    cert = cf.generateCertificate(fis);

    fprintf("=== OPC UA Certificate Compliance (Java fallback) ===\n");
    fprintf("File: %s\n", certFile);
    fprintf("Subject: %s\n", string(cert.getSubjectX500Principal()));
    fprintf("Issuer:  %s\n", string(cert.getIssuerX500Principal()));
    fprintf("Serial:  %s\n", string(cert.getSerialNumber().toString(16)));
    fprintf("Not Before: %s\n", string(cert.getNotBefore()));
    fprintf("Not After:  %s\n", string(cert.getNotAfter()));

    pubKey = cert.getPublicKey();
    if isa(pubKey, "java.security.interfaces.RSAPublicKey")
        keyLen = pubKey.getModulus().bitLength();
        fprintf("RSA Key Length: %d bits %s\n", keyLen, ...
            ternary(keyLen >= 2048, "[PASS]", "[FAIL needs >=2048]"));
    else
        fprintf("Public Key Algorithm: %s (non-RSA)\n", ...
            string(pubKey.getAlgorithm()));
    end

    sigAlg = string(cert.getSigAlgName());
    isSha2Plus = contains(sigAlg, ["SHA256", "SHA384", "SHA512"]);
    fprintf("Signature: %s %s\n", sigAlg, ...
        ternary(isSha2Plus, "[PASS]", "[FAIL needs SHA-256+]"));

    ku = cert.getKeyUsage();
    if ~isempty(ku)
        hasDigSig  = ku(1);
        hasNonRep  = ku(2);
        hasKeyEnc  = ku(3);
        hasDataEnc = ku(4);
        allPresent = hasDigSig && hasNonRep && hasKeyEnc && hasDataEnc;
        fprintf("Key Usage: DigSig=%d NonRep=%d KeyEnc=%d DataEnc=%d %s\n", ...
            hasDigSig, hasNonRep, hasKeyEnc, hasDataEnc, ...
            ternary(allPresent, "[PASS]", "[FAIL missing required bits]"));
    else
        fprintf("Key Usage: [FAIL extension missing]\n");
    end

    try
        san = cert.getSubjectAlternativeNames();
        if isempty(san)
            fprintf("Subject Alt Names: [FAIL missing]\n");
        else
            fprintf("Subject Alt Names: [PASS]\n");
            it = san.iterator();
            while it.hasNext()
                entry = it.next();
                typeId = entry.get(0);
                value  = entry.get(1);
                fprintf("  type=%s value=%s\n", string(typeId), string(value));
            end
        end
    catch ME
        fprintf("Subject Alt Names: error reading (%s)\n", ME.message);
    end

    try
        cert.checkValidity();
        fprintf("Validity: [PASS]\n");
    catch
        fprintf("Validity: [FAIL expired or not yet valid]\n");
    end

    bc = cert.getBasicConstraints();
    fprintf("Basic Constraints: CA=%s %s\n", ...
        ternary(bc == -1, "false", "true (path len " + bc + ")"), ...
        ternary(bc == -1, "[PASS end-entity]", "[FAIL must be end-entity]"));
end

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
% Copyright 2026 The MathWorks, Inc.
