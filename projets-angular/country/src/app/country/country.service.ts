import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpResponse, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Country } from './country';

@Injectable()
export class CountryService {

  constructor(private http: HttpClient) { }

  public getAll(): Observable<Country[]> {
    return this.http.get<Country[]>('http://localhost:8080/country/');
  }
}
