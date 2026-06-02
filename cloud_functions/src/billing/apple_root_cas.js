'use strict';

const https = require('https');

const APPLE_ROOT_CA_URLS = [
  'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',
  'https://www.apple.com/appleca/AppleIncRootCertificate.cer',
];

/** @type {Buffer[] | null} */
let cachedRootCas = null;

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    https
        .get(url, (res) => {
          if (res.statusCode !== 200) {
            reject(new Error(`Failed to fetch ${url}: HTTP ${res.statusCode}`));
            res.resume();
            return;
          }
          const chunks = [];
          res.on('data', (chunk) => chunks.push(chunk));
          res.on('end', () => resolve(Buffer.concat(chunks)));
        })
        .on('error', reject);
  });
}

/**
 * DER-encoded Apple root certificates for SignedDataVerifier.
 * Cached for the lifetime of the Cloud Functions instance.
 */
async function loadAppleRootCertificates() {
  if (cachedRootCas) {
    return cachedRootCas;
  }
  cachedRootCas = await Promise.all(
      APPLE_ROOT_CA_URLS.map((url) => fetchBuffer(url)),
  );
  return cachedRootCas;
}

module.exports = {loadAppleRootCertificates};
