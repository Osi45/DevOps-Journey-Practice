📚 Project2: Quotes API — DevOps Journey Practice

✅ Project Goal  
I designed and implemented a simple Node.js API → containerie with Docker → automae testing, build and deployed with GitHub Actions → interated SonarQube, Npm audit and Trivy for security scanning.

---

🗂️ Project Structure

DevOps-Journey-Practice/
├── .github/                          
│   └── workflows/                    
│       └── ci_pipeline_project2.yml   # GitHub Actions pipeline
├── Project2/
│   ├── app/
│   │   └── index.js                   # Quotes API
│   ├── .gitignore
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── sonar-project.properties
│   └── README.md
├── README.md                          # Main repo README



---

🛠️ Tools & Technologies

| Tool           | Purpose                               |
|----------------|---------------------------------------|
| Node.js        | Quotes API app (Express framework)     |
| Docker         | Containerization                      |
| GitHub Actions | CI/CD Pipeline                         |
| SonarQube      | Code quality & static analysis         |
| Trivy          | Docker image vulnerability scanning    |
| GitHub Secrets | Manage sensitive data (tokens, etc.)   |

---

📋 Main Files

| File                      | Purpose                      |
|---------------------------|------------------------------|
| `index.js` (under /app)   | Express API (Quotes API)      |
| `Dockerfile`              | Containerize the app          |
| `.gitignore`              | Ignore node_modules, etc.     |
| `package.json`            | Node app dependencies         |
| `package-lock.json`       | Lock file for reproducibility |
| `ci_pipeline_project2.yml`| GitHub Actions pipeline       |
| `sonar-project.properties`| SonarQube config              |
| `README.md`               | Project documentation        |


🚀 Step-by-Step Git Commands

1️⃣ Clone the repo:

bash
git clone https://github.com/Osi45/DevOps-Journey-Practice.git
cd DevOps-Journey-Practice


2️⃣ Ceate Project2 directory & files

mkdir Project2
cd Project2
mkdir app
touch app/index.js Dockerfile .gitignore package.json sonar-project.properties README.md
npm init -y
npm install express


3️⃣ Iitialize Git & commit:

git add Project2
git commit -m "Initial commit for Project2 Quotes API"
git push origin main

4️⃣ Udate workflow:

Create .github/workflows/ci_pipeline_project2.yml

git add .github/workflows/ci_pipeline_project2.yml
git commit -m "Add CI/CD pipeline for Project2"
git push origin main

5️⃣ Bild & test Docker image locally:

docker build -t osi45/devops-journey-practice:latest ./Project2
docker run -d -p 8080:3000 osi45/devops-journey-practice:latest

Test:
curl http://localhost:8080/quotes

6️⃣ Push Docker image:

docker login
docker push osi45/devops-journey-practice:latest


7️⃣ CI/CD pipeline will:

✅ Run npm tests
✅ Run npm audit
✅ SonarCloud analysis
✅ Docker build & push
✅ Trivy scan
✅ Slack reports success/failure


🔐 GitHub Secrets

Secret Name              Used For
DOCKERHUB_USERNAME       Docker login
DOCKERHUB_TOKEN          Docker login
SONAR_TOKEN              SonarCloud scan
SLACK_CHANNEL_ID         Slack notification
SLACK_BOT_TOKEN          Slack notification


🎉 Final Workflow

✅ On push to main → pipeline runs automatically
✅ Image built & pushed
✅ Sonar scan runs
✅ Slack reports success/failure
















































