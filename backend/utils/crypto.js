const crypto = require('crypto');
require('dotenv').config();

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
const SEARCH_SALT = process.env.SEARCH_SALT;

function encryptData(text) {
    if (!text || text.trim() === '') return null;
    if (!ENCRYPTION_KEY) return null;

    try {
        const key = Buffer.from(ENCRYPTION_KEY, 'hex');
        const iv = crypto.randomBytes(12);
        const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
        
        let encrypted = cipher.update(text, 'utf8', 'hex');
        encrypted += cipher.final('hex');
        const authTag = cipher.getAuthTag().toString('hex');
        
        return `${iv.toString('hex')}:${authTag}:${encrypted}`;
    } catch (err) {
        console.error('Encryption error:', err);
        return null;
    }
}

function decryptData(encryptedText) {
    if (!encryptedText) return null;
    if (!ENCRYPTION_KEY) return null;

    try {
        const parts = encryptedText.split(':');
        if (parts.length !== 3) return null;

        const [ivHex, authTagHex, encryptedHex] = parts;
        const key = Buffer.from(ENCRYPTION_KEY, 'hex');
        const iv = Buffer.from(ivHex, 'hex');
        const authTag = Buffer.from(authTagHex, 'hex');

        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(authTag);

        let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
        decrypted += decipher.final('utf8');
        
        return decrypted;
    } catch (err) {
        // console.error('Decryption error:', err);
        return null;
    }
}

function getBlindIndex(text) {
    if (!text || text.trim() === '') return null;
    if (!SEARCH_SALT) return null;

    try {
        const key = Buffer.from(SEARCH_SALT, 'hex');
        const normalizedText = text.toLowerCase().trim();
        
        const hmac = crypto.createHmac('sha256', key);
        hmac.update(normalizedText, 'utf8');
        return hmac.digest('hex');
    } catch (err) {
        console.error('Blind index generation error:', err);
        return null;
    }
}

module.exports = {
    encryptData,
    decryptData,
    getBlindIndex
};
