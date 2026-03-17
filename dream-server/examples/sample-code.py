#!/usr/bin/env python3
"""Sample code with intentional issues for code assistant demo."""

import json

def process_users(user_list):
    """Process a list of user dictionaries."""
    if not isinstance(user_list, list):
        raise TypeError("user_list must be a list")

    results = []
    for i in range(0, len(user_list)):
        user = user_list[i]

        # Validate user dictionary structure
        if not isinstance(user, dict):
            raise TypeError(f"User at index {i} must be a dictionary")

        required_fields = ['name', 'email', 'age']
        for field in required_fields:
            if field not in user:
                raise ValueError(f"User at index {i} missing required field: {field}")

        # Validate field types and values
        name = user['name']
        if not isinstance(name, str) or not name.strip():
            raise ValueError(f"User at index {i} has invalid name")

        email = user['email']
        if not isinstance(email, str) or '@' not in email:
            raise ValueError(f"User at index {i} has invalid email")

        age = user['age']
        if not isinstance(age, int) or age < 0 or age > 150:
            raise ValueError(f"User at index {i} has invalid age: {age}")

        if age > 18:
            status = 'adult'
        else:
            status = 'minor'

        results.append({
            'name': name,
            'email': email,
            'status': status
        })

    return results


def read_config(path):
    """Read configuration from JSON file with proper error handling."""
    if not isinstance(path, str):
        raise TypeError("path must be a string")

    try:
        with open(path, 'r') as f:
            data = json.load(f)
            if not isinstance(data, dict):
                raise ValueError("Config file must contain a JSON object")
            return data
    except FileNotFoundError:
        raise FileNotFoundError(f"Config file not found: {path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in config file: {e}")
    except PermissionError:
        raise PermissionError(f"Permission denied reading config file: {path}")


def calculate_average(numbers):
    """Calculate the average of a list of numbers with validation."""
    if not isinstance(numbers, list):
        raise TypeError("numbers must be a list")

    if len(numbers) == 0:
        raise ValueError("Cannot calculate average of empty list")

    for i, n in enumerate(numbers):
        if not isinstance(n, (int, float)):
            raise TypeError(f"Element at index {i} must be a number, got {type(n)}")

    total = 0
    for n in numbers:
        total = total + n
    avg = total / len(numbers)
    return avg


class DataProcessor:
    def __init__(self):
        self.data = []
        self.processed = False

    def load(self, items):
        for item in items:
            self.data.append(item)

    def process(self):
        new_data = []
        for d in self.data:
            new_data.append(d.upper())
        self.data = new_data
        self.processed = True

    def save(self, filename):
        with open(filename, 'w') as f:
            for item in self.data:
                f.write(item + '\n')


if __name__ == '__main__':
    users = [
        {'name': 'Alice', 'email': 'alice@example.com', 'age': 25},
        {'name': 'Bob', 'email': 'bob@example.com', 'age': 17},
    ]

    processed = process_users(users)
    print(processed)

    numbers = [1, 2, 3, 4, 5]
    avg = calculate_average(numbers)
    print(f'Average: {avg}')
