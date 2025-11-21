cat > deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 开始部署 AI 销售教练系统..."

# 安装 Docker（如果未安装）
if ! command -v docker &> /dev/null; then
    echo "📦 安装 Docker..."
    apt update
    apt install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    usermod -aG docker root
fi

# 创建项目目录
mkdir -p /opt/ai-sales-coach
cd /opt/ai-sales-coach

# 创建 docker-compose.yml
cat > docker-compose.yml << 'INNEREOF'
version: '3'
services:
  dify-api:
    image: langgenius/dify-api:0.6.5
    environment:
      - REDIS_HOST=redis
      - POSTGRES_HOST=db
      - CELERY_BROKER_URL=redis://redis:6379/1
      - API_PREFIX=
    ports:
      - "3001:5001"
    depends_on:
      - redis
      - db
    networks:
      - coach-net

  dify-web:
    image: langgenius/dify-web:0.6.5
    ports:
      - "3000:3000"
    environment:
      - CONSOLE_API_URL=http://localhost:3001
      - APP_API_URL=http://localhost:3001
    networks:
      - coach-net

  backend:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./server.js:/app/server.js
      - ./package.json:/app/package.json
      - ./.env:/app/.env
    ports:
      - "3002:3001"
    command: sh -c "npm install && node server.js"
    networks:
      - coach-net

  redis:
    image: redis:7-alpine
    networks:
      - coach-net

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: dify
      POSTGRES_USER: dify
      POSTGRES_PASSWORD: dify123456
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - coach-net

volumes:
  pgdata:

networks:
  coach-net:
    driver: bridge
INNEREOF

# 创建 Node.js 胶水层代码
cat > server.js << 'INNEREOF'
const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

app.post('/api/coach/respond', async (req, res) => {
  try {
    const { sales_input } = req.body;
    const response = await axios.post(
      'http://dify-api:5001/v1/chat-messages',
      {
        inputs: {},
        query: sales_input,
        response_mode: "blocking",
        user: "user_sales_" + Date.now()
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.DIFY_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );

    const answer = response.data.answer;
    // 尝试解析为 JSON，失败则返回原始文本
    let parsed;
    try {
      parsed = JSON.parse(answer);
    } catch (e) {
      parsed = { response: answer, score: 0, feedback: "未结构化输出", stage_complete: false };
    }

    res.json({ success: true, ...parsed });
  } catch (error) {
    console.error('Error:', error.message);
    res.status(500).json({ success: false, error: 'AI 教练暂时不可用' });
  }
});

app.listen(3001, '0.0.0.0', () => {
  console.log('✅ 胶水层运行在 3001 端口');
});
INNEREOF

# 创建 package.json
cat > package.json << 'INNEREOF'
{
  "name": "ai-sales-coach-backend",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "dotenv": "^16.3.1"
  }
}
INNEREOF

# 提示用户输入 API Key
echo ""
read -p "请输入 Dify 应用的 API Key (app-xxxxxx): " DIFY_KEY
read -p "请输入 Qwen-Max API Key (sk-xxxxxx): " QWEN_KEY

# 创建 .env 文件（Dify 内部使用）
cat > .env << EOF
DIFY_API_KEY=$DIFY_KEY
QWEN_API_KEY=$QWEN_KEY
EOF

# 启动服务
echo "🔄 启动 Docker 服务..."
docker compose up -d

echo ""
echo "🎉 部署成功！"
echo "- Dify 控制台: http://$(curl -s ifconfig.me):3000"
echo "- API 接口: http://$(curl -s ifconfig.me):3002/api/coach/respond"
echo "- 请先通过方案创建管理员账号（见文档）"
EOF

# 赋予执行权限
chmod +x deploy.sh

echo "✅ 部署脚本已创建！现在运行："
echo "   ./deploy.sh"
