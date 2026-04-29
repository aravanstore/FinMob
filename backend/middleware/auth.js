const jwt     = require('jsonwebtoken');

module.exports = function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Токен не предоставлен' });

  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Неверный формат токена' });

  try {
    // JWT содержит: { clientId, phone, unionId, dbName }
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.client = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Токен недействителен или истёк' });
  }
};
