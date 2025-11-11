#!/usr/bin/env python3
"""
Script de ejemplo para interactuar con la API de gestión de usuarios FreeRADIUS
"""

import requests
import json
from typing import Dict, List, Optional

class RadiusAPIClient:
    """Cliente para interactuar con la API de FreeRADIUS"""
    
    def __init__(self, api_url: str, api_key: str):
        """
        Inicializa el cliente de la API
        
        Args:
            api_url: URL base de la API (ej: http://192.168.1.100/radius-api.php)
            api_key: API Key para autenticación
        """
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
    
    def _make_request(self, method: str, endpoint: str, data: Optional[Dict] = None, params: Optional[Dict] = None) -> Dict:
        """
        Realiza una petición HTTP a la API
        
        Args:
            method: Método HTTP (GET, POST, PUT, DELETE)
            endpoint: Endpoint de la API
            data: Datos a enviar en el body (para POST/PUT)
            params: Parámetros de query string (para GET)
            
        Returns:
            Respuesta de la API en formato dict
        """
        url = f"{self.api_url}/{endpoint}"
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=self.headers, params=params)
            elif method == 'POST':
                response = requests.post(url, headers=self.headers, json=data)
            elif method == 'PUT':
                response = requests.put(url, headers=self.headers, json=data)
            elif method == 'DELETE':
                response = requests.delete(url, headers=self.headers, params=params)
            else:
                raise ValueError(f"Método HTTP no soportado: {method}")
            
            response.raise_for_status()
            return response.json()
        
        except requests.exceptions.RequestException as e:
            print(f"Error en la petición: {e}")
            return {'success': False, 'message': str(e)}
    
    def login(self) -> bool:
        """
        Verifica la conexión con la API
        
        Returns:
            True si la conexión es exitosa
        """
        data = {'api_key': self.api_key}
        response = self._make_request('POST', 'login', data=data)
        return response.get('success', False)
    
    def get_stats(self) -> Dict:
        """
        Obtiene estadísticas generales
        
        Returns:
            Diccionario con total_users y active_sessions
        """
        response = self._make_request('GET', 'stats')
        if response.get('success'):
            return response.get('data', {})
        return {}
    
    def list_users(self, limit: int = 50, offset: int = 0, search: str = '') -> List[Dict]:
        """
        Lista usuarios
        
        Args:
            limit: Número máximo de usuarios a retornar
            offset: Offset para paginación
            search: Término de búsqueda
            
        Returns:
            Lista de diccionarios con información de usuarios
        """
        params = {
            'limit': limit,
            'offset': offset
        }
        if search:
            params['search'] = search
        
        response = self._make_request('GET', 'users', params=params)
        if response.get('success'):
            return response.get('data', {}).get('users', [])
        return []
    
    def create_user(self, username: str, password: str, 
                   bandwidth_up: str = '10M', bandwidth_down: str = '10M',
                   profile: str = '') -> bool:
        """
        Crea un nuevo usuario
        
        Args:
            username: Nombre de usuario (ej: usuario@dominio)
            password: Contraseña del usuario
            bandwidth_up: Velocidad de upload (ej: 10M, 50M, 100M)
            bandwidth_down: Velocidad de download
            profile: Perfil/grupo del usuario (opcional)
            
        Returns:
            True si el usuario se creó exitosamente
        """
        data = {
            'username': username,
            'password': password,
            'bandwidth_up': bandwidth_up,
            'bandwidth_down': bandwidth_down,
            'profile': profile
        }
        
        response = self._make_request('POST', 'users', data=data)
        if response.get('success'):
            print(f"✅ Usuario '{username}' creado exitosamente")
            return True
        else:
            print(f"❌ Error al crear usuario: {response.get('message')}")
            return False
    
    def get_user(self, username: str) -> Optional[Dict]:
        """
        Obtiene información de un usuario específico
        
        Args:
            username: Nombre del usuario
            
        Returns:
            Diccionario con información del usuario o None
        """
        params = {'username': username}
        response = self._make_request('GET', 'user', params=params)
        if response.get('success'):
            return response.get('data', {})
        return None
    
    def update_user(self, username: str, password: Optional[str] = None,
                   bandwidth_up: Optional[str] = None, 
                   bandwidth_down: Optional[str] = None) -> bool:
        """
        Actualiza un usuario existente
        
        Args:
            username: Nombre del usuario a actualizar
            password: Nueva contraseña (opcional)
            bandwidth_up: Nueva velocidad de upload (opcional)
            bandwidth_down: Nueva velocidad de download (opcional)
            
        Returns:
            True si se actualizó correctamente
        """
        data = {'username': username}
        
        if password:
            data['password'] = password
        if bandwidth_up:
            data['bandwidth_up'] = bandwidth_up
        if bandwidth_down:
            data['bandwidth_down'] = bandwidth_down
        
        response = self._make_request('PUT', 'user', data=data)
        if response.get('success'):
            print(f"✅ Usuario '{username}' actualizado exitosamente")
            return True
        else:
            print(f"❌ Error al actualizar usuario: {response.get('message')}")
            return False
    
    def delete_user(self, username: str) -> bool:
        """
        Elimina un usuario
        
        Args:
            username: Nombre del usuario a eliminar
            
        Returns:
            True si se eliminó correctamente
        """
        params = {'username': username}
        response = self._make_request('DELETE', 'user', params=params)
        if response.get('success'):
            print(f"✅ Usuario '{username}' eliminado exitosamente")
            return True
        else:
            print(f"❌ Error al eliminar usuario: {response.get('message')}")
            return False


def main():
    """Ejemplo de uso de la clase RadiusAPIClient"""
    
    # Configuración
    API_URL = 'http://192.168.1.100/radius-api.php'  # Cambiar por tu URL
    API_KEY = 'tu_api_key_secreta_aqui'              # Cambiar por tu API Key
    
    # Crear cliente
    client = RadiusAPIClient(API_URL, API_KEY)
    
    # Verificar conexión
    print("🔄 Verificando conexión con la API...")
    if not client.login():
        print("❌ No se pudo conectar con la API. Verifica la URL y API Key.")
        return
    
    print("✅ Conexión exitosa!\n")
    
    # Obtener estadísticas
    print("📊 Estadísticas:")
    stats = client.get_stats()
    print(f"   Total de usuarios: {stats.get('total_users', 0)}")
    print(f"   Sesiones activas: {stats.get('active_sessions', 0)}\n")
    
    # Crear un usuario de ejemplo
    print("➕ Creando usuario de ejemplo...")
    client.create_user(
        username='cliente1@fibra',
        password='password123',
        bandwidth_up='50M',
        bandwidth_down='50M',
        profile='default'
    )
    print()
    
    # Listar usuarios
    print("📋 Listando primeros 10 usuarios:")
    users = client.list_users(limit=10)
    for user in users:
        print(f"   - {user['username']}")
    print()
    
    # Buscar un usuario específico
    print("🔍 Buscando usuario 'cliente1'...")
    users = client.list_users(search='cliente1')
    if users:
        print(f"   Encontrado: {users[0]['username']}")
    print()
    
    # Obtener detalles de un usuario
    print("📄 Obteniendo detalles del usuario 'cliente1@fibra'...")
    user_details = client.get_user('cliente1@fibra')
    if user_details:
        print(f"   Usuario encontrado con {len(user_details.get('check', []))} atributos")
    print()
    
    # Actualizar usuario
    print("✏️ Actualizando velocidad del usuario...")
    client.update_user(
        username='cliente1@fibra',
        bandwidth_up='100M',
        bandwidth_down='100M'
    )
    print()
    
    # Eliminar usuario (descomenta para probar)
    # print("🗑️ Eliminando usuario de ejemplo...")
    # client.delete_user('cliente1@fibra')
    # print()
    
    print("✅ Ejemplos completados!")


if __name__ == '__main__':
    main()
