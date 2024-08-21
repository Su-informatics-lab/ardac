# Use the official Python 3.10 image from the Docker Hub
FROM python:3.10

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Create a virtual environment named "dict"
RUN python -m venv venvs/dict

#RUN /app/venvs/dict/bin/pip install setuptools -U

# Install Poetry
#RUN /app/venvs/dict/bin/pip install poetry

# Install dependencies using Poetry
#RUN /app/venvs/dict/bin/poetry install -v

# Install pytest
#RUN /app/venvs/dict/bin/pip install pytest -U

# Ensure the script has executable permissions
RUN chmod +x /app/packages_install.sh

# Run the packages_install.sh script
RUN /bin/bash /app/packages_install.sh

# Make the script executable
RUN chmod +x run_tests.sh

RUN chmod +x json2yml.sh

RUN chmod +x dictcompare.sh

# Command to run the script
CMD ["/bin/bash", "/app/run_tests.sh"]

