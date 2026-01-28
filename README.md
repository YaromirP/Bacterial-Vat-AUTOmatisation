# Bacterial-Vat-AUTOmatisation
Автоматический контроль "Ваток" для создания целых кластеров в системе

Инструкция по установке:
1) Устанавливаем на угол Bacterial Vat на ОДИНАКОВЫХ координатах Х и Z снизу Radio Hatch и сверху Output Hatch
2) На Output Hatch Ставим транспозер из OpenComputers и на него ставим 2 адаптера:<img width="539" height="632" alt="image" src="https://github.com/user-attachments/assets/db03faf0-d030-48a0-9519-3ac4b5ba9103" />
3) Привязываем MFU к Radio & Output Hatch, для удобства устанавливаем MFU(Radio Hatch) в нижний адаптер и MFU(Output Hatch) в верхний
4) С любой из сторон света транспозера ставим ME Dual Interface
5) К Radio Hatch подключаем поставку предметов из МЕ системы:<img width="406" height="703" alt="image" src="https://github.com/user-attachments/assets/dd13d3c1-6101-45cf-88ff-0202ede10c27" />
6) Запускаем серверную стойку (Желательно) и заранее установив OpenOS вводим комманду: wget https://raw.githubusercontent.com/YaromirP/Bacterial-Vat-AUTOmatisation/refs/heads/main/BacVatAUTO.lua BacVatAUTO.lua
7) Запускаем программу BacVatAUTO.lua и нас встречает простенький интерфейс:<img width="1589" height="1001" alt="image" src="https://github.com/user-attachments/assets/7b331a5f-df84-43cc-af2c-0a57488aa95b" />
8) Нас просят в самом начале работы программы инициализировать подключенные устройства:<img width="255" height="208" alt="image" src="https://github.com/user-attachments/assets/f15ef3e7-4837-42ae-9cae-7a91c0838786" />
9) Первым делом вводим название жидкости, которую будем автоматизировать (У меня это Mutagen), обязательно вводим ПОЛНОЕ название жижи:<img width="276" height="262" alt="image" src="https://github.com/user-attachments/assets/0ca7c2f6-26fe-4b7c-a2c4-9f5582cead6c" />
10) Далее нас спрашивают, при каком потоке машинка должна работать, можем установить любое удобное или идеальное значение "1001"
11) Дальше при обнаружении Жидкости в нескольких Output Hatch у нас спросят, какой транспозер будет отвечать за нашу машинку, у меня их 4шт!:<img width="623" height="390" alt="image" src="https://github.com/user-attachments/assets/cf29e35d-e637-4c6d-906c-baa87942b4d1" />
12) Выбираем любой и переходим к настройке, для начала найдем наш транспозер по его id:<img width="608" height="471" alt="image" src="https://github.com/user-attachments/assets/461a029b-3d30-41bf-82cb-2d6419340d69" /> <img width="575" height="637" alt="image" src="https://github.com/user-attachments/assets/dd35bf50-0e61-4e5a-8682-2e2b6b890e6a" />
13) После нахождения нужного транспозера, встаем на конструкцию из транспозера и адаптеров  и смотрим наши координаты X & Z, затем выбираем соответствующий по координатам транспозера Radio Hatch, у меня например это 4:<img width="617" height="518" alt="image" src="https://github.com/user-attachments/assets/7fd4fb5b-711b-4d80-9f36-1a5eb82f9c59" />
14) Посвторяем так для каждого кластера повторяющихся по одному типу Жидкости
15) Как только закончили с добавлением кластеров разберем функционал кнопочек:<img width="243" height="182" alt="image" src="https://github.com/user-attachments/assets/89d9a530-ed25-4e50-8b2c-73b604502ad3" />
16) За что отвечают кнопки:
"1" - Добавляем новый кластер Bacterial Vat, если добавили еще машинок
"2" - Изменяем желаемый поток для определенного Output Hatch (вдруг вы ошиблись)
"3" - Ручное отключение Radio Hatch'a если нам надо что-то поменять в конструкции Bacterial Vat
"4" - Действует как и "3", но уже включает Radio Hatch
"5" - Удаление кластера из системы (Вдруг вы решили изменить местоположение машинки...)
"6" - Вывод списка кластеров (Название жижи, Заданный макс порог производства, состояние ON/OFF, id транспозера
"0" - Выход из программы

Поздравляю, вы прошли подготовительный курс по использованию BacVatAUTO!!!
